import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data.dart';
import '../../../data/models.dart';
import '../../../theme.dart';

/// Bill history for the Billing section.
///
/// Until now the app could *create* bills but had nowhere to look one up:
/// a bill was only visible from the customer it belonged to, from the
/// Pending Payments page (and only while it was unpaid), or aggregated
/// beyond recognition in Reports. So "what did we bill this morning" and
/// "pull up that invoice again" had no answer. This is that answer, and it
/// lives inside Billing rather than as yet another top-level page.
class OwnerBillHistoryView extends StatefulWidget {
  final AppData state;

  /// Opens a bill's customer, when the host page can navigate there.
  final void Function(Customer customer)? onOpenCustomer;

  const OwnerBillHistoryView({
    super.key,
    required this.state,
    this.onOpenCustomer,
  });

  @override
  State<OwnerBillHistoryView> createState() => _OwnerBillHistoryViewState();
}

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _rupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

String _timeAgo(DateTime? when) {
  if (when == null) return '-';
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24 && now.day == when.day) {
    final h = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final m = when.minute.toString().padLeft(2, '0');
    return '$h:$m ${when.hour < 12 ? 'AM' : 'PM'}';
  }
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.day} ${_kMonths[when.month - 1]}';
}

bool _isToday(DateTime? d) {
  if (d == null) return false;
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

class _OwnerBillHistoryViewState extends State<OwnerBillHistoryView> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bill> _visibleBills() {
    final q = _searchController.text.toLowerCase().trim();

    // Newest first - a history that opens on the oldest bill is a list you
    // have to scroll to the bottom of to use.
    final bills = [...widget.state.bills]..sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    return bills.where((bill) {
      switch (_filter) {
        case 'Today':
          if (!_isToday(bill.createdAt)) return false;
          break;
        case 'Unpaid':
          if (bill.isFullyPaid) return false;
          break;
        case 'Paid':
          if (!bill.isFullyPaid) return false;
          break;
      }
      if (q.isEmpty) return true;
      final customerName = _customerNameFor(bill).toLowerCase();
      return bill.invoiceNumber.toLowerCase().contains(q) || customerName.contains(q);
    }).toList();
  }

  String _customerNameFor(Bill bill) {
    if (bill.customerName?.isNotEmpty == true) return bill.customerName!;
    final match = widget.state.customers.where((c) => c.id == bill.customerId);
    return match.isEmpty ? 'Walk-in' : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final bills = _visibleBills();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final todayBills = widget.state.bills.where((b) => _isToday(b.createdAt)).toList();
    final todayRevenue = todayBills.fold<double>(0, (s, b) => s + b.finalAmount);
    final outstanding = widget.state.bills.fold<double>(0, (s, b) => s + b.amountDue);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _summaryTile(
                          label: 'Billed today',
                          value: _rupees(todayRevenue),
                          detail: '${todayBills.length} bill${todayBills.length == 1 ? '' : 's'}',
                          color: AppTheme.accentGreen,
                          bg: AppTheme.accentGreenBg,
                          icon: PhosphorIconsFill.trendUp,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryTile(
                          label: 'Outstanding',
                          value: _rupees(outstanding),
                          detail: outstanding > 0 ? 'Awaiting collection' : 'All collected',
                          color: outstanding > 0 ? AppTheme.accentAmber : AppTheme.slateLight,
                          bg: outstanding > 0 ? AppTheme.accentAmberBg : const Color(0xFFF1F5F9),
                          icon: PhosphorIconsFill.handCoins,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search invoice number or client',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 18,
                        color: AppTheme.slateLight,
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(PhosphorIconsBold.x, size: 15),
                              color: AppTheme.slateLight,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in const ['All', 'Today', 'Unpaid', 'Paid'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _filterChip(f),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: bills.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _billCard(context, bills[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required String detail,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slateLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.slateDark,
              letterSpacing: -0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    var count = 0;
    switch (label) {
      case 'All':
        count = widget.state.bills.length;
        break;
      case 'Today':
        count = widget.state.bills.where((b) => _isToday(b.createdAt)).length;
        break;
      case 'Unpaid':
        count = widget.state.bills.where((b) => !b.isFullyPaid).length;
        break;
      case 'Paid':
        count = widget.state.bills.where((b) => b.isFullyPaid).length;
        break;
    }

    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.slateMedium,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final searching = _searchController.text.trim().isNotEmpty || _filter != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.receipt, size: 30, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No bills match this view' : 'No bills yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.slateDark,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              searching
                  ? 'Try a different filter or clear the search.'
                  : 'Bills you create appear here, newest first.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billCard(BuildContext context, Bill bill) {
    final paid = bill.isFullyPaid;
    final partial = !paid && bill.amountPaid > 0;
    final statusColor = paid
        ? AppTheme.accentGreen
        : (partial ? AppTheme.accentAmber : AppTheme.accentRed);
    final statusBg = paid
        ? AppTheme.accentGreenBg
        : (partial ? AppTheme.accentAmberBg : AppTheme.accentRedBg);
    final statusLabel = paid ? 'Paid' : (partial ? 'Part paid' : 'Unpaid');

    final itemCount = bill.items.fold<int>(0, (s, i) => s + i.quantity);

    return InkWell(
      onTap: () => showBillDetailSheet(context, bill: bill, state: widget.state),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(PhosphorIconsFill.receipt, size: 20, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customerNameFor(bill),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.slateDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bill.invoiceNumber}  ·  $itemCount item${itemCount == 1 ? '' : 's'}  ·  ${_timeAgo(bill.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slateLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _rupees(bill.finalAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slateDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!paid) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmberBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.warningCircle, size: 13, color: AppTheme.accentAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_rupees(bill.amountDue)} still due'
                        '${partial ? ' · ${_rupees(bill.amountPaid)} collected' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The itemised receipt for one bill.
///
/// Read-only on purpose: bills are immutable once written (see the
/// corresponding rule in firestore.rules), so this shows what was charged
/// rather than offering an edit that the rules would reject anyway.
/// Collecting an outstanding balance is a *payment*, and lives on the
/// Pending Payments page under the same Billing gear.
Future<void> showBillDetailSheet(
  BuildContext context, {
  required Bill bill,
  required AppData state,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      final customerMatch = state.customers.where((c) => c.id == bill.customerId);
      final customerName = bill.customerName?.isNotEmpty == true
          ? bill.customerName!
          : (customerMatch.isEmpty ? 'Walk-in' : customerMatch.first.name);
      final when = bill.createdAt;
      final dateLabel = when == null
          ? 'Date unknown'
          : '${when.day} ${_kMonths[when.month - 1]} ${when.year}, '
              '${(when.hour % 12 == 0 ? 12 : when.hour % 12)}:'
              '${when.minute.toString().padLeft(2, '0')} '
              '${when.hour < 12 ? 'AM' : 'PM'}';

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.slateDark,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bill.invoiceNumber}  ·  $dateLabel',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.slateLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(PhosphorIconsBold.x, size: 15, color: AppTheme.slateMedium),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in bill.items) _billItemRow(item, state),
                        const Divider(height: 24, color: AppTheme.borderSubtle),
                        _totalRow('Subtotal', _rupees(bill.subTotal)),
                        if (bill.discountAmount > 0)
                          _totalRow(
                            'Discount',
                            '-${_rupees(bill.discountAmount)}',
                            valueColor: AppTheme.accentGreen,
                          ),
                        if (bill.taxAmount > 0) _totalRow('GST', _rupees(bill.taxAmount)),
                        const SizedBox(height: 6),
                        _totalRow('Total', _rupees(bill.finalAmount), emphasise: true),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: bill.isFullyPaid ? AppTheme.accentGreenBg : AppTheme.accentAmberBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                bill.isFullyPaid
                                    ? PhosphorIconsFill.checkCircle
                                    : PhosphorIconsFill.clock,
                                size: 17,
                                color: bill.isFullyPaid ? AppTheme.accentGreen : AppTheme.accentAmber,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  bill.isFullyPaid
                                      ? 'Paid in full via ${bill.paymentMethod}'
                                      : '${_rupees(bill.amountPaid)} collected · ${_rupees(bill.amountDue)} outstanding',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: bill.isFullyPaid
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _billItemRow(BillItem item, AppData state) {
  final name = item.serviceName ??
      item.productName ??
      _lookupItemName(item, state) ??
      (item.type == 'SERVICE' ? 'Service' : 'Product');

  var staffName = item.employeeName;
  if (staffName == null || staffName.isEmpty) {
    final match = state.employees.where((e) => e.id == item.employeeId);
    staffName = match.isEmpty ? null : match.first.name;
  }

  final lineTotal = item.unitPrice * item.quantity - item.discountAmount;

  return Padding(
    padding: const EdgeInsets.only(bottom: 11.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: item.type == 'SERVICE' ? AppTheme.primaryLight : const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.type == 'SERVICE' ? PhosphorIconsFill.scissors : PhosphorIconsFill.package,
            size: 15,
            color: item.type == 'SERVICE' ? AppTheme.primaryBlue : AppTheme.statTeal,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.quantity > 1 ? '$name  ×${item.quantity}' : name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateDark,
                ),
              ),
              if (staffName != null && staffName.isNotEmpty)
                Text(
                  'by $staffName',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slateLight,
                  ),
                ),
            ],
          ),
        ),
        Text(
          _rupees(lineTotal),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.slateDark,
          ),
        ),
      ],
    ),
  );
}

/// Bills store the name they were written with, but older rows may not have
/// one - fall back to the live catalog rather than printing a bare id.
String? _lookupItemName(BillItem item, AppData state) {
  if (item.serviceId != null) {
    final match = state.services.where((s) => s.id == item.serviceId);
    if (match.isNotEmpty) return match.first.name;
  }
  if (item.inventoryItemId != null) {
    final match = state.inventory.where((p) => p.id == item.inventoryItemId);
    if (match.isNotEmpty) return match.first.name;
  }
  return null;
}

Widget _totalRow(String label, String value, {bool emphasise = false, Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasise ? 14.5 : 12.5,
            fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
            color: emphasise ? AppTheme.slateDark : AppTheme.slateLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasise ? 17 : 12.5,
            fontWeight: emphasise ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppTheme.slateDark,
            letterSpacing: emphasise ? -0.5 : 0,
          ),
        ),
      ],
    ),
  );
}
