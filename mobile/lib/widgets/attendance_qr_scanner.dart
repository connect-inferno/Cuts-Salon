import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/attendance_qr.dart';
import '../theme.dart';

/// Opens the camera to scan the owner's attendance QR. Returns the scanned
/// code, or null if the person backed out.
///
/// Camera only, on purpose: there is no "pick from gallery" here, so a
/// photo someone forwarded can't be fed in. (The real guard is the code
/// changing every 30 seconds and firestore.rules refusing an old one - this
/// just doesn't make cheating easy.)
Future<AttendanceQrCode?> scanAttendanceQr(BuildContext context, {required String salonId, required bool clockingOut}) {
  return Navigator.of(context).push<AttendanceQrCode>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AttendanceQrScanner(salonId: salonId, clockingOut: clockingOut),
    ),
  );
}

class _AttendanceQrScanner extends StatefulWidget {
  final String salonId;
  final bool clockingOut;

  const _AttendanceQrScanner({required this.salonId, required this.clockingOut});

  @override
  State<_AttendanceQrScanner> createState() => _AttendanceQrScannerState();
}

class _AttendanceQrScannerState extends State<_AttendanceQrScanner> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    facing: CameraFacing.back,
  );
  String? _hint;
  bool _done = false;
  bool _stalled = false;
  Timer? _stallTimer;

  /// Browsers only open the camera on https:// or localhost. Over a plain
  /// http:// address (e.g. a dev server opened by its network IP) an iPhone
  /// gives no error at all - the preview just stays black - so say so up
  /// front instead.
  static bool get _insecureWeb {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    return uri.scheme != 'https' && !const {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(uri.host);
  }

  @override
  void initState() {
    super.initState();
    // Some browsers neither start the camera nor report an error. After a
    // while with no picture, explain instead of leaving a black screen.
    _stallTimer = Timer(const Duration(seconds: 10), () {
      final v = _controller.value;
      if (mounted && !v.isRunning && v.error == null) setState(() => _stalled = true);
    });
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = AttendanceQrCode.tryParse(barcode.rawValue);
      if (code == null) {
        _setHint("That isn't the attendance QR. Scan the code on the owner's Attendance QR screen.");
        continue;
      }
      if (code.salonId != widget.salonId) {
        _setHint('That attendance QR belongs to a different salon.');
        continue;
      }
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  void _setHint(String hint) {
    if (_hint != hint && mounted) setState(() => _hint = hint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // Explicit, because the app theme's title style and icon colour
        // (dark, for white app bars) would otherwise win on this black one.
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.clockingOut ? 'Scan to clock out' : 'Scan to clock in'),
      ),
      body: _insecureWeb
          ? const _CameraMessage(
              title: 'The camera needs a secure link',
              body: 'Phones only open the camera on an https:// address. Open Stylux from its usual link and try again.',
            )
          : _stalled
              ? const _CameraMessage(
                  title: "The camera didn't start",
                  body: 'Allow the camera for this site in your browser settings, close other apps using the camera, then try again.',
                )
              : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          // Aiming square.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _hint ?? "Point the camera at the QR on the owner's screen.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hint == null ? Colors.white : AppTheme.accentAmberBg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
  }
}

class _CameraError extends StatelessWidget {
  final MobileScannerException error;

  const _CameraError({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return _CameraMessage(
      title: denied
          ? 'Camera access is needed to clock in'
          : unsupported
              ? "This device's camera can't scan here"
              : "Couldn't start the camera",
      body: denied
          ? 'Allow the camera for Stylux in your browser or phone settings, then try again.'
          : 'Try another browser (Chrome or Safari), or ask the owner to mark you in.',
    );
  }
}

class _CameraMessage extends StatelessWidget {
  final String title;
  final String body;

  const _CameraMessage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsRegular.cameraSlash, color: Colors.white, size: 44),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
