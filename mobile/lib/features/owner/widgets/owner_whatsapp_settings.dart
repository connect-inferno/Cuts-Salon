import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/support_contact.dart';
import '../../../theme.dart';
import '../../../widgets/open_link.dart';

/// Settings > WhatsApp: the owner's on/off switch for automatic messages,
/// plus two buttons for checking the setup works.
///
/// The messages themselves are sent by the Cloud Functions in
/// functions/index.js from the salon's own WhatsApp Business number; this
/// card only flips settings/main.whatsappEnabled and files requests for
/// those functions. A salon whose functions were never deployed can still
/// flip the switch - nothing is sent, and the test button says why.
class OwnerWhatsAppCard extends ConsumerStatefulWidget {
  const OwnerWhatsAppCard({super.key});

  @override
  ConsumerState<OwnerWhatsAppCard> createState() => _OwnerWhatsAppCardState();
}

class _OwnerWhatsAppCardState extends ConsumerState<OwnerWhatsAppCard> {
  final _testPhoneController = TextEditingController();
  bool _savingSwitch = false;
  // Which request is in flight ('test' / 'daily'), so only that button spins.
  String? _running;
  String? _lastResult;
  bool _lastFailed = false;

  @override
  void dispose() {
    _testPhoneController.dispose();
    super.dispose();
  }

  // Saved straight away rather than with the business form above it: it's
  // a single switch with its own effect, and bundling it into that form's
  // Save would let an unrelated edit turn messaging on or off.
  Future<void> _toggle(bool on) async {
    setState(() => _savingSwitch = true);
    try {
      await ref.read(appDataProvider.notifier).updateSettings({'whatsappEnabled': on});
    } catch (e) {
      _snack(e.toString(), failed: true);
    } finally {
      if (mounted) setState(() => _savingSwitch = false);
    }
  }

  Future<void> _run(String type) async {
    final phone = _testPhoneController.text.trim();
    if (type == 'test' && phone.isEmpty) {
      _snack('Enter the phone number to send the test to.', failed: true);
      return;
    }
    setState(() {
      _running = type;
      _lastResult = null;
    });
    try {
      final result = await ref
          .read(appDataProvider.notifier)
          .runWhatsAppRequest(type, phone: type == 'test' ? phone : null);
      if (mounted) {
        setState(() {
          _lastResult = result;
          _lastFailed = false;
        });
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _lastResult = message;
          _lastFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  void _snack(String text, {bool failed = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: failed ? AppTheme.accentRed : AppTheme.accentGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appDataProvider).valueOrNull?.settings;
    // Not set up for this salon yet: offer to set it up instead of a switch
    // that would do nothing (see SalonFirestore.isWhatsAppReady).
    if (settings?.whatsappReady != true) return const _WhatsAppNotSetUpCard();
    final enabled = settings?.whatsappEnabled ?? false;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsFill.whatsappLogo, size: 16, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Messages',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sent automatically from your salon\'s WhatsApp Business number, only to clients marked "OK to send WhatsApp messages".',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              key: const Key('whatsappEnabledSwitch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: enabled,
              onChanged: _savingSwitch ? null : _toggle,
              title: const Text(
                'Send automatic WhatsApp messages',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              subtitle: Text(
                enabled ? 'On - messages go out as described below.' : 'Off - no WhatsApp messages are sent.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _bullet(PhosphorIconsRegular.receipt, 'The bill, right after it is created'),
          _bullet(PhosphorIconsRegular.cake, 'Birthday wishes, at 10:00 AM on the day'),
          _bullet(PhosphorIconsRegular.clockCounterClockwise, 'A "come back" reminder 21 days after the last visit'),
          const Divider(height: 28, color: Color(0xFFF1F5F9)),
          const Text(
            'CHECK THE SETUP',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('whatsappTestPhone'),
                  controller: _testPhoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Your number',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: const Icon(PhosphorIconsRegular.phone, size: 18, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _actionButton(type: 'test', label: 'Send test', icon: PhosphorIconsRegular.paperPlaneTilt),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _actionButton(
              type: 'daily',
              label: 'Send today\'s birthday & reminder messages now',
              icon: PhosphorIconsRegular.play,
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastFailed ? AppTheme.accentRedBg : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _lastResult!,
                key: const Key('whatsappResult'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _lastFailed ? AppTheme.accentRed : const Color(0xFF166534),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
          ],
        ),
      );

  Widget _actionButton({required String type, required String label, required IconData icon}) {
    final busy = _running == type;
    return OutlinedButton.icon(
      key: Key('whatsappRun_$type'),
      onPressed: _running != null ? null : () => _run(type),
      icon: busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 15, color: const Color(0xFF16A34A)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFBBF7D0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/// Shown in place of the WhatsApp switch until this salon's WhatsApp has
/// been set up by the Stylux team: what it does, and how to ask for it.
class _WhatsAppNotSetUpCard extends StatelessWidget {
  const _WhatsAppNotSetUpCard();

  void _open(BuildContext context, String url) {
    if (!openLink(url)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open that here. Email $kSupportEmail instead.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    const message = "Hi, I'd like to set up automatic WhatsApp messages for my salon on Stylux.";
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                child: const Icon(PhosphorIconsFill.whatsappLogo, size: 18, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'WhatsApp messages',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.slateDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
                child: const Text('Not set up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Send every bill, birthday wishes and "come back" reminders automatically - from your own WhatsApp Business number.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.slateMedium),
          ),
          const SizedBox(height: 6),
          const Text(
            'It is not set up for your salon yet. Contact us and we will set it up for you.',
            style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.slateLight),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _open(context, 'https://wa.me/$kSupportWhatsApp?text=${Uri.encodeComponent(message)}'),
                  icon: const Icon(PhosphorIconsFill.whatsappLogo, size: 17),
                  label: const Text('WhatsApp us'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(
                    context,
                    'mailto:$kSupportEmail?subject=${Uri.encodeComponent('WhatsApp messages for my salon')}&body=${Uri.encodeComponent(message)}',
                  ),
                  icon: const Icon(PhosphorIconsRegular.envelopeSimple, size: 17),
                  label: const Text('Email us'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'You can already tick "OK to send WhatsApp messages" on clients - those ticks are used once it is switched on.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateLight),
          ),
        ],
      ),
    );
  }
}
