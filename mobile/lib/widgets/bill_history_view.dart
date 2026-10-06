import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';

/// Bill history for the Billing section.
///
/// Until now the app could *create* bills but had nowhere to look one up:
/// a bill was only visible from the customer it belonged to, from the
/// Pending Payments page (and only while it was unpaid), or aggregated
/// beyond recognition in Reports. So "what did we bill this morning" and
/// "pull up that invoice again" had no answer. This is that answer, and it
/// lives inside Billing rather than as yet another top-level page.
class BillHistoryView extends StatefulWidget {
  final AppData state;

  /// Opens a bill's customer, when the host page can navigate there.
  final void Function(Customer customer)? onOpenCustomer;

  /// Opens the reports page.
  final VoidCallback? onOpenReports;

  /// When set, only bills this employee worked on are listed, and the
  /// summary tiles count only those. Staff see their own counter, the owner
  /// sees the salon's - same widget, so the two can never drift into
  /// formatting a bill differently.
  final String? onlyEmployeeId;

  const BillHistoryView({
    super.key,
    required this.state,
    this.onOpenCustomer,
    this.onOpenReports,
    this.onlyEmployeeId,
  });

  @override
  State<BillHistoryView> createState() => _BillHistoryViewState();
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

/// Pinned header for the bill history list.
///
/// The header used to sit outside the scroll view entirely, so the summary
/// tiles, search box and filters ate a fixed slice of the screen no matter
/// how far down the list you were. This scrolls it instead - but pinned, and
/// collapsing rather than leaving: the two tiles shrink into a single-line
/// strip and the search box and filter chips stay put, so the list gets most
/// of the viewport without the figures or the controls going away.
///
/// A pinned header has to declare its extents before laying anything out, so
/// the three heights below are fixed. Every widget measured by them is
/// single-line (maxLines: 1 / ellipsis), which is what makes that safe -
/// `bill_history_header_test.dart` pumps this at several widths and fails on
/// any overflow if one of these drifts out of date.
class _HistoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget controls;

  const _HistoryHeaderDelegate({required this.controls});

  static const double _controlsH = 100; // search field + 12 gap + chip row
  static const double _topPad = 14;
  static const double _bottomPad = 12;

  @override
  double get maxExtent => _topPad + _controlsH + _bottomPad;

  @override
  double get minExtent => _topPad + _controlsH + _bottomPad;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.bgSurface,
      padding: const EdgeInsets.fromLTRB(16, _topPad, 16, _bottomPad),
      child: controls,
    );
  }

  @override
  bool shouldRebuild(_HistoryHeaderDelegate old) => old.controls != controls;
}

class _BillHistoryViewState extends State<BillHistoryView> {
  final _searchController = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Every bill this view is allowed to show, before search and filters.
  List<Bill> get _scopedBills {
    final id = widget.onlyEmployeeId;
    if (id == null) return widget.state.bills;
    return widget.state.bills
        .where((b) => b.items.any((i) => i.employeeId == id))
        .toList();
  }

  List<Bill> _visibleBills() {
    final q = _searchController.text.toLowerCase().trim();

    // Newest first - a history that opens on the oldest bill is a list you
    // have to scroll to the bottom of to use.
    final bills = [..._scopedBills]..sort((a, b) {
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

    final scoped = _scopedBills;
    final todayBills = scoped.where((b) => _isToday(b.createdAt)).toList();

    // Payment-method breakdown from today's bills only.
    // Collected amounts rather than billed totals, each under the method it
    // actually arrived by - a balance later cleared by card is card money,
    // not the bill's original method's.
    double todayCash = 0, todayUpi = 0, todayCard = 0;
    for (final b in todayBills) {
      b.collectedByMethod.forEach((method, amount) {
        switch (method) {
          case 'UPI':
            todayUpi += amount;
          case 'CARD':
            todayCard += amount;
          default:
            // CASH, and anything taken at the counter on a PENDING bill
            // (no method recorded for it), which was always shown as cash.
            todayCash += amount;
        }
      });
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
        child: CustomScrollView(
          slivers: [
            // Today's Collections table — scrolls away with the list so it
            // doesn't compete for space with the pinned search header.
            SliverToBoxAdapter(
              child: _todayCollectionsTable(
                cash: todayCash,
                upi: todayUpi,
                card: todayCard,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HistoryHeaderDelegate(
                controls: _searchAndFilters(),
              ),
            ),
            if (bills.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                sliver: SliverList.separated(
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

  // ── Today's Collections table ─────────────────────────────────────────────

  Widget _todayCollectionsTable({
    required double cash,
    required double upi,
    required double card,
  }) {
    final total = cash + upi + card;
    int pct(double v) => total > 0 ? (v / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.currencyInr,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Expanded + ellipsis: unbounded, these overflowed the card
                  // on a narrow phone or with a large system font size.
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Collections",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Cash · UPI · Card received today',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Column headers
            Container(
              color: const Color(0xFFF8F9FC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'METHOD',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'COLLECTED',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SHARE',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cash
            _collectionRow(
              icon: PhosphorIconsBold.money,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFECFDF5),
              label: 'Cash',
              amount: cash,
              share: pct(cash),
              accentColor: const Color(0xFF10B981),
              divider: true,
            ),

            // UPI
            _collectionRow(
              icon: PhosphorIconsBold.qrCode,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFF5F3FF),
              label: 'UPI / QR',
              amount: upi,
              share: pct(upi),
              accentColor: const Color(0xFF8B5CF6),
              divider: true,
            ),

            // Card
            _collectionRow(
              icon: PhosphorIconsBold.creditCard,
              iconColor: const Color(0xFF0EA5E9),
              iconBg: const Color(0xFFE0F2FE),
              label: 'Card',
              amount: card,
              share: pct(card),
              accentColor: const Color(0xFF0EA5E9),
              divider: false,
            ),

            // Total row
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Total Collected',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3730A3),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _rupees(total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3730A3),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      '100%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.onOpenReports != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: InkWell(
                    onTap: widget.onOpenReports,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'View All Reports',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(PhosphorIconsBold.arrowRight, size: 14, color: Color(0xFF4F46E5)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

  Widget _collectionRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color accentColor,
    required String label,
    required double amount,
    required int share,
    required bool divider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: iconColor, size: 15),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _rupees(amount),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: amount > 0
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFCBD5E1),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$share%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: amount > 0 ? accentColor : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (divider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
      ],
    );
  }



  /// Search box and filter chips. These stay pinned at every scroll offset -
  /// they are how you drive the list, so losing them mid-scroll would mean
  /// scrolling back to the top to change a filter.
  Widget _searchAndFilters() {
    return Column(
      children: [
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
        Expanded(
          child: SingleChildScrollView(
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
        ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    final scoped = _scopedBills;
    var count = 0;
    switch (label) {
      case 'All':
        count = scoped.length;
        break;
      case 'Today':
        count = scoped.where((b) => _isToday(b.createdAt)).length;
        break;
      case 'Unpaid':
        count = scoped.where((b) => !b.isFullyPaid).length;
        break;
      case 'Paid':
        count = scoped.where((b) => b.isFullyPaid).length;
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
