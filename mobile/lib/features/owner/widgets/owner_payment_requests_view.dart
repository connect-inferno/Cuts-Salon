import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models.dart';
import '../../../data/payment_requests_provider.dart';
import '../../../theme.dart';
import '../../../widgets/async_state_views.dart';

String _rupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Settlement requests raised by staff, for the owner to approve or refuse.
///
/// Approving is what actually records the payment - see
/// PaymentRequestsNotifier.resolve, which runs recordPayment's transaction
/// first and stamps the request second, so the money and the customer's
/// outstanding balance move together or not at all.
class OwnerPaymentRequestsView extends ConsumerWidget {
  const OwnerPaymentRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentRequestsProvider);
    return async.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(
        error: err,
        onRetry: () => ref.read(paymentRequestsProvider.notifier).refresh(),
      ),
      data: (requests) => _buildBody(context, ref, requests),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<PaymentRequest> requests) {
    final pending = requests.where((r) => r.status == 'PENDING').toList();
    final decided = requests.where((r) => r.status != 'PENDING').toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(paymentRequestsProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isEmpty)
              _emptyState()
            else ...[
              Text(
                'Waiting on you',
                style: _sectionStyle,
              ),
              const SizedBox(height: 10),
              for (final r in pending) ...[
                _requestCard(context, ref, r, actionable: true),
                const SizedBox(height: 10),
              ],
            ],
            if (decided.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Decided', style: _sectionStyle),
              const SizedBox(height: 10),
              for (final r in decided) ...[
                _requestCard(context, ref, r, actionable: false),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static const _sectionStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    color: Color(0xFF64748B),
  );

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        children: [
          Icon(PhosphorIconsRegular.checkCircle, size: 32, color: Color(0xFF16A34A)),
          SizedBox(height: 10),
          Text(
            'No settlement requests waiting',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 4),
          Text(
            'Staff cannot record a payment themselves - when they collect a '
            'balance it arrives here for you to approve.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(
    BuildContext context,
    WidgetRef ref,
    PaymentRequest r, {
    required bool actionable,
  }) {
    final approved = r.status == 'APPROVED';
    final when = r.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customerName ?? 'Client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.invoiceNumber ?? 'Bill'} · ${r.method}'
                      '${when == null ? '' : ' · ${when.day} ${_kMonths[when.month - 1]}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _rupees(r.amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(PhosphorIconsRegular.userCircle, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Collected by ${r.requestedByName ?? 'staff'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                r.note!,
                style: const TextStyle(fontSize: 11.5, height: 1.35, color: Color(0xFF475467)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (actionable)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(context, ref, r, approve: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: Color(0xFFFECDCA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: const Text('Refuse', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(context, ref, r, approve: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    child: const Text(
                      'Approve & record',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: approved ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                approved ? 'APPROVED · payment recorded' : 'REFUSED',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: approved ? const Color(0xFF10B981) : AppTheme.accentRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    PaymentRequest r, {
    required bool approve,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(paymentRequestsProvider.notifier).resolve(r.id, approve: approve);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${_rupees(r.amount)} recorded against ${r.invoiceNumber ?? 'the bill'}.'
                : 'Request refused. The balance stays open.',
          ),
          backgroundColor: approve ? AppTheme.accentGreen : AppTheme.accentAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
