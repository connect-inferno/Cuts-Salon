import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/attendance_qr.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import '../../../widgets/ds.dart';

/// The owner's attendance QR: put this on a phone or tablet at the counter
/// and staff clock in and out by scanning it.
///
/// A new code every [attendanceQrRotation] for as long as the screen is open.
/// Closing it stops the codes - nobody can punch until it is open again - so
/// the screen is kept awake while it shows. Each code is shown only after
/// the server has saved it (AppDataNotifier.rotateAttendanceQr); if a save
/// fails, the old code stays up until it would have expired, then the QR is
/// replaced by a "can't refresh" note rather than showing a code every scan
/// would refuse.
class AttendanceQrPage extends ConsumerStatefulWidget {
  const AttendanceQrPage({super.key});

  @override
  ConsumerState<AttendanceQrPage> createState() => _AttendanceQrPageState();
}

class _AttendanceQrPageState extends ConsumerState<AttendanceQrPage> {
  // firestore.rules accepts a code for 45s from when it was issued.
  static const _codeLifetime = Duration(seconds: 45);

  String? _branchId;
  String? _payload;
  DateTime? _shownAt;
  String? _error;
  bool _rotating = false;
  Timer? _rotateTimer;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable().catchError((_) {});
    // Repaints the countdown, and notices when a failed refresh has left the
    // code on screen past its lifetime.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _tick?.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  void _startBranch(String branchId) {
    if (_branchId == branchId) return;
    _branchId = branchId;
    _payload = null;
    _shownAt = null;
    _error = null;
    _rotateTimer?.cancel();
    _rotate();
    _rotateTimer = Timer.periodic(attendanceQrRotation, (_) => _rotate());
  }

  Future<void> _rotate() async {
    final branchId = _branchId;
    if (branchId == null || _rotating) return;
    _rotating = true;
    try {
      final payload = await ref.read(appDataProvider.notifier).rotateAttendanceQr(branchId);
      if (!mounted || branchId != _branchId) return;
      setState(() {
        _payload = payload;
        _shownAt = DateTime.now();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _rotating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appDataProvider).valueOrNull;
    final branches = (state?.branches ?? const <Branch>[]).where((b) => b.active).toList();
    if (_branchId == null && branches.isNotEmpty) {
      // After this frame: _startBranch triggers a network call and setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _branchId == null) _startBranch(branches.first.id);
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: const Text('Attendance QR'),
        backgroundColor: AppTheme.cardBg,
        foregroundColor: AppTheme.slateDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (branches.length > 1) ...[
                  const DsSectionLabel('Branch'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in branches)
                        ChoiceChip(
                          label: Text(b.name),
                          selected: b.id == _branchId,
                          onSelected: (_) => setState(() => _startBranch(b.id)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (branches.isEmpty)
                  const DsCard(child: Text('Add a branch first (Settings > Branches) - the QR belongs to a branch.'))
                else
                  _buildQrCard(branches),
                const SizedBox(height: 16),
                const DsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How staff use it', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                      SizedBox(height: 8),
                      Text(
                        'Staff open Stylux, tap Clock in (or Clock out) and point their camera at this code. '
                        'The code changes every 30 seconds, so a photo of it stops working almost at once. '
                        'Keep this screen open while staff arrive and leave - when it is closed, nobody can punch.',
                        style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.slateMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrCard(List<Branch> branches) {
    final shownAt = _shownAt;
    final age = shownAt == null ? null : DateTime.now().difference(shownAt);
    final expired = age != null && age >= _codeLifetime;
    final secondsLeft = age == null
        ? attendanceQrRotation.inSeconds
        : (attendanceQrRotation.inSeconds - age.inSeconds).clamp(0, attendanceQrRotation.inSeconds);
    final branchName = branches.where((b) => b.id == _branchId).map((b) => b.name).firstOrNull ?? '';

    Widget body;
    if (_payload != null && !expired) {
      body = Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: QrImageView(
              key: ValueKey(_payload),
              data: _payload!,
              size: 260,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.slateDark),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppTheme.slateDark),
            ),
          ),
          const SizedBox(height: 14),
          DsProgressBar(value: secondsLeft / attendanceQrRotation.inSeconds),
          const SizedBox(height: 8),
          Text(
            secondsLeft == 0 ? 'Changing now…' : 'New code in ${secondsLeft}s',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateMedium),
          ),
        ],
      );
    } else if (_error != null || expired) {
      body = Column(
        children: [
          const Icon(PhosphorIconsRegular.wifiSlash, size: 40, color: AppTheme.accentRed),
          const SizedBox(height: 10),
          const Text(
            "Can't refresh the code",
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.slateDark),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? 'Check the internet connection on this device.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _rotate, child: const Text('Try again')),
        ],
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DsCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Scan to clock in or out',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppTheme.slateDark),
          ),
          if (branchName.isNotEmpty) ...[
            const SizedBox(height: 4),
            DsPill(branchName),
          ],
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}
