import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/app_data_provider.dart';
import '../theme.dart';

/// One line under "Bill Generated" saying whether the bill is going to the
/// client on WhatsApp. The sending itself is automatic (the
/// whatsappBillReceipt Cloud Function fires when the bill is saved); this
/// only tells staff whether it will, so nobody hands over a paper bill
/// "just in case" or promises one that isn't coming.
///
/// Shows nothing while the salon's WhatsApp switch is off.
class BillWhatsAppNote extends ConsumerWidget {
  final String customerId;

  const BillWhatsAppNote({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider).valueOrNull;
    // Both: switched on AND actually set up. A salon could flip the switch
    // before WhatsApp was configured, and this used to then say the bill
    // was going out when nothing would be sent.
    if (data?.settings?.whatsappEnabled != true || data?.settings?.whatsappReady != true) {
      return const SizedBox.shrink();
    }
    final matches = data!.customers.where((c) => c.id == customerId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final customer = matches.first;
    final optedIn = customer.whatsappOptIn;
    final firstName = customer.name.trim().split(' ').first;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: optedIn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIconsFill.whatsappLogo,
              size: 16,
              color: optedIn ? const Color(0xFF16A34A) : AppTheme.slateLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                optedIn
                    ? 'Bill is being sent to $firstName on WhatsApp.'
                    : 'Not sent on WhatsApp - $firstName hasn\'t agreed to WhatsApp messages.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: optedIn ? const Color(0xFF166534) : AppTheme.slateMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
