import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/qr_image.dart';
import '../../../firebase/salon_qr.dart';
import '../../../theme.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/ds.dart';
import '../../auth/auth_provider.dart';

/// Wording and icon for each QR, shared by the Profile card, the Home
/// header buttons and the full-screen view.
extension QrKindText on QrKind {
  String get title => switch (this) {
        QrKind.payment => 'Payment QR',
        QrKind.review => 'Google review QR',
      };

  IconData get icon => switch (this) {
        QrKind.payment => PhosphorIconsRegular.qrCode,
        QrKind.review => PhosphorIconsRegular.star,
      };

  /// What to upload, in the Profile card.
  String get uploadHint => switch (this) {
        QrKind.payment => 'Your UPI or bank QR - clients scan it to pay.',
        QrKind.review => 'From your Google Business Profile ("Ask for reviews") - clients scan it to review you.',
      };

  /// The line shown above the QR when it is held up to a client.
  String get caption => switch (this) {
        QrKind.payment => 'Scan to pay with any UPI app',
        QrKind.review => 'Enjoyed your visit? Scan to review us on Google',
      };
}

String? _qrUrl(WidgetRef ref, QrKind kind) {
  final s = ref.watch(appDataProvider).valueOrNull?.settings;
  final url = kind == QrKind.payment ? s?.paymentQrUrl : s?.reviewQrUrl;
  return (url == null || url.isEmpty) ? null : url;
}

/// Picks an image, shrinks it (data/qr_image.dart), uploads it and saves
/// its URL to settings/main. Returns true when the new QR is saved.
Future<bool> pickAndUploadQr(BuildContext context, WidgetRef ref, QrKind kind) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text, {bool error = false}) => messenger.showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.accentRed : AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ));

  final salonId = ref.read(authControllerProvider).salonId;
  if (salonId == null) {
    say('Please sign in again and retry.', error: true);
    return false;
  }

  // The picker already scales big photos down on the device, so the Dart
  // shrinking below has less to chew through (it runs on the UI thread on
  // the web).
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600);
  } catch (_) {
    say('Could not open your photos.', error: true);
    return false;
  }
  if (file == null) return false; // cancelled

  try {
    final jpeg = compressQrImage(await file.readAsBytes());
    final url = await uploadSalonQr(salonId: salonId, kind: kind, jpeg: jpeg);
    await ref.read(appDataProvider.notifier).updateSettings({kind.settingsField: url});
    say('${kind.title} saved.');
    return true;
  } on FormatException {
    say('That file is not an image - pick a photo or screenshot of the QR.', error: true);
  } catch (e) {
    say(e.toString().replaceFirst('Exception: ', ''), error: true);
  }
  return false;
}

/// Both QR codes, in the owner's Profile: add, change or remove.
class OwnerQrCodesCard extends ConsumerStatefulWidget {
  const OwnerQrCodesCard({super.key});

  @override
  ConsumerState<OwnerQrCodesCard> createState() => _OwnerQrCodesCardState();
}

class _OwnerQrCodesCardState extends ConsumerState<OwnerQrCodesCard> {
  final _busy = <QrKind>{};

  Future<void> _upload(QrKind kind) async {
    setState(() => _busy.add(kind));
    await pickAndUploadQr(context, ref, kind);
    if (mounted) setState(() => _busy.remove(kind));
  }

  Future<void> _remove(QrKind kind) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Remove ${kind.title}?',
        subtitle: 'It will no longer show from the Home screen. You can add it again any time.',
        icon: PhosphorIconsRegular.trash,
        iconColor: AppTheme.accentRed,
        actions: AppDialogActions(
          onCancel: () => Navigator.pop(ctx, false),
          submitLabel: 'Remove',
          submitColor: AppTheme.accentRed,
          onSubmit: () => Navigator.pop(ctx, true),
        ),
        child: const SizedBox.shrink(),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(kind));
    try {
      await ref.read(appDataProvider.notifier).updateSettings({kind.settingsField: null});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not remove it: $e'),
          backgroundColor: AppTheme.accentRed,
        ));
      }
    }
    if (mounted) setState(() => _busy.remove(kind));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DsSectionLabel('QR codes'),
        DsCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _row(QrKind.payment),
              const Divider(height: 1, indent: 72, color: AppTheme.borderSubtle),
              _row(QrKind.review),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Upload a photo or screenshot of each QR. It is shrunk to a small file and shown '
            'from the buttons at the top of Home, ready to show a client.',
            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.slateLight),
          ),
        ),
      ],
    );
  }

  Widget _row(QrKind kind) {
    final url = _qrUrl(ref, kind);
    final busy = _busy.contains(kind);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          _QrThumb(url: url, icon: kind.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                const SizedBox(height: 2),
                Text(
                  url == null ? kind.uploadHint : 'Added - shown from the Home screen',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.slateLight, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            TextButton(onPressed: () => _upload(kind), child: Text(url == null ? 'Add' : 'Change')),
            if (url != null)
              IconButton(
                tooltip: 'Remove',
                onPressed: () => _remove(kind),
                icon: const Icon(PhosphorIconsRegular.trash, size: 18, color: AppTheme.slateLight),
              ),
          ],
        ],
      ),
    );
  }
}

class _QrThumb extends StatelessWidget {
  final String? url;
  final IconData icon;

  const _QrThumb({required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: url == null
          ? Icon(icon, size: 20, color: AppTheme.primaryBlue)
          : _QrImage(url: url!, fit: BoxFit.cover),
    );
  }
}

/// The stored image. On the web, Flutter fetches images itself and needs
/// the bucket to send CORS headers; `fallback` shows it with a plain <img>
/// when it doesn't, so a missing bucket CORS setting can't blank the QR.
class _QrImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _QrImage({required this.url, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (_, __, ___) => const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(PhosphorIconsRegular.imageBroken, color: AppTheme.slateLight),
        ),
      ),
    );
  }
}

/// The QR held up to a client, opened from the Home header: big, on white,
/// with the salon's name and a one-line instruction. Before one is added
/// it offers to add it right there.
class QrDisplayView extends ConsumerStatefulWidget {
  final QrKind kind;

  const QrDisplayView({super.key, required this.kind});

  @override
  ConsumerState<QrDisplayView> createState() => _QrDisplayViewState();
}

class _QrDisplayViewState extends ConsumerState<QrDisplayView> {
  bool _busy = false;

  Future<void> _upload() async {
    setState(() => _busy = true);
    await pickAndUploadQr(context, ref, widget.kind);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final url = _qrUrl(ref, kind);
    final salonName = ref.watch(appDataProvider).valueOrNull?.settings?.salonName ?? '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: url == null ? _empty(kind) : _qr(kind, url, salonName),
        ),
      ),
    );
  }

  Widget _qr(QrKind kind, String url, String salonName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Column(
            children: [
              if (salonName.isNotEmpty)
                Text(salonName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              Text(kind.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.slateMedium)),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(color: Colors.white, child: _QrImage(url: url)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: _busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : TextButton.icon(
                  onPressed: _upload,
                  icon: const Icon(PhosphorIconsRegular.uploadSimple, size: 16),
                  label: const Text('Change QR'),
                ),
        ),
      ],
    );
  }

  Widget _empty(QrKind kind) {
    return DsCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(16)),
            child: Icon(kind.icon, size: 26, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 14),
          Text(kind == QrKind.payment ? 'No payment QR yet' : 'No Google review QR yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
          const SizedBox(height: 6),
          Text(kind.uploadHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _upload,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(PhosphorIconsRegular.uploadSimple, size: 18),
              label: Text(_busy ? 'Uploading...' : 'Upload ${kind.title}'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('You can also manage both QR codes in your Profile.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
