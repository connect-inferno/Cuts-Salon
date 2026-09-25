import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/app_dialog.dart';

String _rupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _shortDate(DateTime? d) => d == null ? '-' : '${d.day} ${_kMonths[d.month - 1]}';

int _daysOld(DateTime? d) => d == null ? 0 : DateTime.now().difference(d).inDays;

/// One client's unpaid bills, rolled up.
class _ClientDue {
  final Customer customer;
  final List<Bill> unpaidBills;
  final double total;
  final int oldestDays;

  _ClientDue({
    required this.customer,
    required this.unpaidBills,
    required this.total,
    required this.oldestDays,
  });
}

/// "Who owes us what." Bills are immutable, so an unpaid balance isn't a flag
/// on the bill that gets flipped - it's finalAmount minus everything
/// collected (at the counter plus the payments ledger). This screen groups
/// those leftovers by client and lets the owner record a settlement.
class OwnerDuesTab extends ConsumerWidget {
  const OwnerDuesTab({super.key});

  /// Derived from the loaded bills rather than from customers.outstandingBalance,
  /// because the owner needs to see *which* bills make up the total, not just
  /// the number. The denormalized balance stays the fast path for the
  /// customer list; this is the itemized view.
  List<_ClientDue> _buildDues(AppData state) {
    final byCustomer = <String, List<Bill>>{};
    for (final bill in state.bills) {
      if (bill.isFullyPaid) continue;
      (byCustomer[bill.customerId] ??= []).add(bill);
    }

    final all = [...state.customers, ...state.archivedCustomers];
    final dues = <_ClientDue>[];
    byCustomer.forEach((customerId, bills) {
      final match = all.where((c) => c.id == customerId);
      // A bill whose client record has vanished still owes money, so it gets
      // a placeholder rather than being dropped from the total.
      final customer = match.isNotEmpty
          ? match.first
          : Customer(
              id: customerId,
              name: bills.first.customerName ?? 'Unknown client',
              phone: '-',
              isVip: false,
              branchId: '',
            );
      bills.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
      dues.add(_ClientDue(
        customer: customer,
        unpaidBills: bills,
        total: bills.fold(0.0, (sum, b) => sum + b.amountDue),
        oldestDays: _daysOld(bills.first.createdAt),
      ));
    });

    dues.sort((a, b) => b.total.compareTo(a.total));
    return dues;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      data: (state) => _buildContent(context, ref, state),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final dues = _buildDues(state);
    final grandTotal = dues.fold(0.0, (sum, d) => sum + d.total);

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTotalCard(grandTotal, dues),
            const SizedBox(height: 18),

            if (dues.isEmpty)
              _buildEmptyState()
            else
              ...dues.map((due) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildClientCard(context, ref, due),
                  )),

            // This page is always embedded under a header that names it,
            // so it no longer draws its own title - and it is never behind
            // the floating nav bar, so the 110px clearance is gone too.
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard(double grandTotal, List<_ClientDue> dues) {
    // "Overdue" here just means the oldest unpaid bill is more than a month
    // old - there are no payment terms in this app to breach, so it's a
    // nudge, not a status.
    final staleCount = dues.where((d) => d.oldestDays > 30).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(PhosphorIconsFill.handCoins, size: 22, color: Color(0xFFB45309)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL OUTSTANDING',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 3),
                Text(
                  _rupees(grandTotal),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: Color(0xFF78350F)),
                ),
                if (staleCount > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '$staleCount client${staleCount == 1 ? '' : 's'} waiting over 30 days',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        children: [
          Icon(PhosphorIconsRegular.checkCircle, size: 34, color: Color(0xFF16A34A)),
          SizedBox(height: 10),
          Text(
            'No pending payments',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          SizedBox(height: 4),
          Text(
            'Bills marked "LATER" at checkout will appear here.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(BuildContext context, WidgetRef ref, _ClientDue due) {
    final isStale = due.oldestDays > 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFEF3C7),
                child: Text(
                  due.customer.name.isNotEmpty ? due.customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309), fontSize: 14),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      due.customer.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      due.customer.phone,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _rupees(due.total),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: -0.4),
                  ),
                  Text(
                    '${due.unpaidBills.length} bill${due.unpaidBills.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          if (isStale) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsFill.warningCircle, size: 11, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    'Oldest bill is ${due.oldestDays} days old',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          for (final bill in due.unpaidBills) _buildBillRow(context, ref, bill),
        ],
      ),
    );
  }

  Widget _buildBillRow(BuildContext context, WidgetRef ref, Bill bill) {
    final partial = bill.paymentStatus == 'PARTIAL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bill.invoiceNumber,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: partial ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        partial ? 'PART PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: partial ? const Color(0xFF2563EB) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  partial
                      ? '${_shortDate(bill.createdAt)} • ${_rupees(bill.amountPaid)} of ${_rupees(bill.finalAmount)} paid'
                      : '${_shortDate(bill.createdAt)} • ${_rupees(bill.finalAmount)} total',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _rupees(bill.amountDue),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showRecordPaymentDialog(context, ref, bill),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                'Collect',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, WidgetRef ref, Bill bill) {
    // Pre-filled with the full outstanding amount, since settling in full is
    // far and away the common case; they can overwrite it for an instalment.
    final amountController = TextEditingController(text: bill.amountDue.toStringAsFixed(0));
    String method = 'CASH';
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.handCoins,
          title: 'Record Payment',
          subtitle: '${bill.customerName ?? 'Client'} • ${bill.invoiceNumber}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Outstanding',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Text(
                      _rupees(bill.amountDue),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setDialogState(() {}),
                decoration: appDialogFieldDecoration(
                  label: 'Amount received *',
                  icon: PhosphorIconsRegular.currencyInr,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'PAID BY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: ['CASH', 'UPI', 'CARD'].map((m) {
                  final isSel = method == m;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setDialogState(() => method = m),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
                            border: Border.all(
                              color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                              width: isSel ? 1.6 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              m,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Record Payment',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter an amount greater than zero.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).recordPayment(
                      billId: bill.id,
                      amount: amount,
                      method: method,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  final remaining = bill.amountDue - amount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(remaining > 0.009
                          ? '${_rupees(amount)} recorded. ${_rupees(remaining)} still outstanding.'
                          : '${_rupees(amount)} recorded. ${bill.invoiceNumber} is fully paid.'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
