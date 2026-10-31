import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data_provider.dart';
import '../../../data/support_contact.dart';
import '../../../theme.dart';
import '../../../widgets/app_sub_page.dart';
import '../../../widgets/ds.dart';
import '../../../widgets/open_link.dart';
import 'owner_whatsapp_page.dart';

/// Settings > Business: a short pointer to Menu > WhatsApp, where the
/// owner runs the automatic messages (owner_whatsapp_page.dart). Until
/// WhatsApp is set up for the salon it's the "contact us" card instead.
class OwnerWhatsAppCard extends ConsumerWidget {
  const OwnerWhatsAppCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appDataProvider).valueOrNull?.settings;
    if (settings?.whatsappReady != true) return const WhatsAppNotSetUpCard();
    final on = settings?.whatsappEnabled ?? false;
    return DsCard(
      onTap: () => openAppSubPage(
        context,
        title: 'WhatsApp',
        subtitle: 'Automatic messages to clients',
        child: const OwnerWhatsAppPage(),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTheme.accentGreenBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(PhosphorIconsFill.whatsappLogo, size: 19, color: Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WhatsApp messages',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.slateDark)),
                const SizedBox(height: 2),
                Text(
                  on ? 'On. Bill receipts, birthday wishes and reminders - set them up here.' : 'Off. Open to switch on and choose what gets sent.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight, size: 15, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

/// The two setup checks: a test message to the owner's own number, and
/// running today's birthday and reminder messages now. Both are requests
/// the Cloud Function answers (see SalonFirestore.runWhatsAppRequest).
class WhatsAppSetupChecks extends ConsumerStatefulWidget {
  const WhatsAppSetupChecks({super.key});

  @override
  ConsumerState<WhatsAppSetupChecks> createState() => _WhatsAppSetupChecksState();
}

class _WhatsAppSetupChecksState extends ConsumerState<WhatsAppSetupChecks> {
  final _testPhoneController = TextEditingController();
  // Which request is in flight ('test' / 'daily'), so only that button spins.
  String? _running;
  String? _lastResult;
  bool _lastFailed = false;

  @override
  void dispose() {
    _testPhoneController.dispose();
    super.dispose();
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
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Send a test to your own number, or send today's birthday and reminder messages without waiting for 10:00 AM.",
            style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.slateMedium),
          ),
          const SizedBox(height: 12),
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
class WhatsAppNotSetUpCard extends StatelessWidget {
  const WhatsAppNotSetUpCard({super.key});

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
