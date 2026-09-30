import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models.dart';
import '../../data/payment_requests_provider.dart';
import '../../widgets/async_state_views.dart';

String _rupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The staff member's own settlement requests and what became of them.
///
/// The provider scopes the query to `requestedBy` for a non-owner, so this
/// never holds anyone else's. Its job is to close the loop: without it, a
/// staff member who collected a balance at the counter has no way to tell
/// whether the owner has accepted it.
class EmployeePaymentRequestsView extends ConsumerWidget {
  const EmployeePaymentRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paymentRequestsProvider);
    return async.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(
        error: err,
        onRetry: () => ref.read(paymentRequestsProvider.notifier).refresh(),
      ),
      data: (requests) => RefreshIndicator(
        onRefresh: () => ref.read(paymentRequestsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: requests.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    for (final r in requests) ...[
                      _card(r),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

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
          Icon(PhosphorIconsRegular.paperPlaneTilt, size: 30, color: Color(0xFFCBD5E1)),
          SizedBox(height: 10),
          Text(
            'No requests sent yet',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 4),
          Text(
            'When you collect an unpaid balance, the request you send your '
            'owner appears here with their decision.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _card(PaymentRequest r) {
    final (label, fg, bg) = switch (r.status) {
      'APPROVED' => ('APPROVED', const Color(0xFF10B981), const Color(0xFFECFDF5)),
      'REJECTED' => ('REFUSED', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      _ => ('WAITING', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
    };
    final when = r.createdAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.customerName ?? 'Client',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.invoiceNumber ?? 'Bill'} · ${r.method}'
                  '${when == null ? '' : ' · ${when.day} ${_kMonths[when.month - 1]}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(r.amount),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
