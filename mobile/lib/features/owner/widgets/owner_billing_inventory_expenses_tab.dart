import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/bill_math.dart';
import '../../../data/client_package.dart';
import '../../../data/expenses_provider.dart';
import '../../../data/models.dart';
import '../../../data/client_search.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/searchable_picker.dart';
import '../../../widgets/bill_whatsapp_note.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/bill_history_view.dart';
import '../../../widgets/add_customer_page.dart';
import '../../../router.dart';
import '../../../widgets/app_sub_page.dart';
import 'owner_packages_page.dart' show packageDate;
import 'owner_reports_page.dart';
import 'service_picker_page.dart';
import '../../../data/money.dart';
import '../../../data/service_menu.dart';

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

const String _kAllBranches = 'All branches';


/// Day only. An expense is logged against a date (stored as midnight), not
/// a moment - formatting it with a time printed "12:00 AM" on every one.
String _formatDay(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// --- BILLING TAB ---

enum _BillingSection { newBill, history }

class OwnerBillingTab extends StatefulWidget {
  final String? preselectedCustomerId;
  final VoidCallback? onOpenNotifications;

  const OwnerBillingTab({super.key, this.preselectedCustomerId, this.onOpenNotifications});

  @override
  State<OwnerBillingTab> createState() => _OwnerBillingTabState();
}

class _OwnerBillingTabState extends State<OwnerBillingTab> {
  // Billing opens on New Bill: ringing up a client is what this tab is for
  // at the counter, and Home's "New bill" button lands here - it used to
  // open on History, so that button needed a second tap to do its job.
  _BillingSection _section = _BillingSection.newBill;
  String? _selectedCustomerId;
  String? _selectedEmployeeId;
  String? _selectedBranchId;
  // The branch History is showing; null = all of them. Separate from the
  // bill's branch so browsing the past can't change where a new bill goes.
  String? _historyBranchId;
  final Set<String> _selectedServiceIds = {};
  final Map<String, int> _selectedProductQuantities = {};
  // Which side of the menu the pick screen opens on: Gents, Ladies, or null
  // for all.
  String? _serviceAudience;
  // What each price-varies service on this bill is being charged.
  final Map<String, double> _servicePrices = {};
  // Spend the client's package credit on this bill, when they have some.
  bool _usePackage = true;
  double _discountPercent = 0.0;
  String _paymentMethod = 'UPI';
  // Set only when _paymentMethod == 'PENDING': how much the client is
  // handing over right now, with the rest becoming a due against them.
  // Empty/0 means they're paying the whole bill later.
  final _partPaymentController = TextEditingController();
  // Method used for the portion collected up front on a PENDING bill.
  String _partPaymentMethod = 'CASH';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
    // Landing on History is the default, but being handed a client means
    // someone tapped "bill this client" - that has to open the form.
    if (widget.preselectedCustomerId != null) {
      _section = _BillingSection.newBill;
    }
  }

  @override
  void didUpdateWidget(OwnerBillingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preselectedCustomerId != null &&
        widget.preselectedCustomerId != _selectedCustomerId) {
      _selectedCustomerId = widget.preselectedCustomerId;
      _section = _BillingSection.newBill;
    }
  }

  @override
  void dispose() {
    _partPaymentController.dispose();
    super.dispose();
  }

  /// The branch in the header: which one this bill is for on New Bill, and
  /// which to show on History. Only a salon with several branches has a
  /// choice.
  Widget? _buildBranchButton(BuildContext context, AppData state) {
    if (state.branches.length < 2) return null;
    final history = _section == _BillingSection.history;
    final selected = state.branches.where((b) => b.id == (history ? _historyBranchId : _selectedBranchId));
    final label = selected.isNotEmpty
        ? selected.first.name
        : (history ? _kAllBranches : state.branches.first.name);
    return Tooltip(
      message: history ? 'Show bills from' : 'Branch for this bill',
      child: InkWell(
        onTap: () async {
          if (history) {
            final names = {for (final b in state.branches) b.id: b.name};
            final picked = await showSearchablePicker<String>(
              context: context,
              title: 'Show bills from',
              items: [_kAllBranches, ...names.keys],
              labelOf: (id) => names[id] ?? _kAllBranches,
              searchHint: 'Search branches',
            );
            if (picked != null) setState(() => _historyBranchId = names.containsKey(picked) ? picked : null);
            return;
          }
          final branch = await showSearchablePicker<Branch>(
            context: context,
            title: 'Bill from which branch?',
            items: state.branches,
            labelOf: (b) => b.name,
            subtitleOf: (b) => b.address ?? '',
            searchHint: 'Search branches',
          );
          if (branch != null) setState(() => _selectedBranchId = branch.id);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsRegular.storefront, size: 15, color: AppTheme.primaryBlue),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(PhosphorIconsBold.caretDown, size: 11, color: AppTheme.slateLight),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error:
              (err, st) => AppErrorView(
                error: err,
                onRetry: () => ref.read(appDataProvider.notifier).refresh(),
              ),
          data: (state) => _buildShell(context, ref, state),
        );
      },
    );
  }

  /// Billing is a section with two views, not a single form.
  ///
  /// It used to be the create-bill form and nothing else, which is why
  /// there was nowhere to look a bill up: a bill left the screen the moment
  /// it was saved and only reappeared, partially, on three other pages. The
  /// segmented control keeps both jobs in the one place people look.
  Widget _buildShell(BuildContext context, WidgetRef ref, AppData state) {
    // Set here, not in _buildBody: the header's branch button needs it too.
    _selectedBranchId ??=
        state.branches.isNotEmpty ? state.branches.first.id : null;

    final now = DateTime.now();
    final billedToday =
        state.bills.where((b) {
          final d = b.createdAt;
          return d != null &&
              d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        }).length;

    return Container(
      color: AppTheme.bgSurface,
      child: Column(
        children: [
          AppPageHeader(
            title: 'Billing',
            subtitle:
                billedToday > 0
                    ? '$billedToday bill${billedToday == 1 ? '' : 's'} today'
                    : 'No bills yet today',
            showDivider: false,
            trailing: _buildBranchButton(context, state),
            actions: [
              // The bell, like every tab: discount and payment requests
              // used to live behind a "Billing settings" gear here, next to
              // the GST switch, so daily approvals looked like settings.
              AppPageAction(
                icon: PhosphorIconsRegular.bell,
                tooltip: 'Requests',
                badgeCount: state.pendingPaymentRequestCount,
                onTap: () => widget.onOpenNotifications?.call(),
              ),
            ],
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildSegmentedControl(),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          Expanded(
            child:
                _section == _BillingSection.history
                    ? BillHistoryView(
                        state: state,
                        // A branch that has since gone falls back to all.
                        branchId: state.branches.any((b) => b.id == _historyBranchId) ? _historyBranchId : null,
                        onOpenReports: () => openAppSubPage(
                          context,
                          title: 'Reports',
                          subtitle: 'Takings, profit, team, clients and stock - month by month',
                          // New bill from a client opened in the Clients
                          // report: their page has closed itself, so close
                          // Reports too and start the bill right here.
                          child: OwnerReportsTab(
                            onStartBill: (customer) {
                              Navigator.of(context).pop();
                              setState(() {
                                _selectedCustomerId = customer.id;
                                _section = _BillingSection.newBill;
                              });
                            },
                          ),
                        ),
                      )
                    : _buildBody(context, ref, state),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // New Bill first: it's the default and the main job of this tab.
          for (final section in const [
            _BillingSection.newBill,
            _BillingSection.history,
          ])
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _section = section),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        _section == section ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow:
                        _section == section
                            ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section == _BillingSection.newBill
                            ? PhosphorIconsBold.plusCircle
                            : PhosphorIconsBold.clockCounterClockwise,
                        size: 15,
                        color:
                            _section == section
                                ? AppTheme.primaryBlue
                                : AppTheme.slateLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section == _BillingSection.newBill
                            ? 'New Bill'
                            : 'History',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              _section == section
                                  ? AppTheme.primaryBlue
                                  : AppTheme.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final selectedCustomer =
        _selectedCustomerId == null
            ? null
            : _firstOrNull(
              state.customers.where((c) => c.id == _selectedCustomerId),
            );
    // Staff removed from the team (active: false) can't be billed against.
    final billableStaff = state.employees.where((e) => e.active).toList();
    final selectedEmployee =
        _selectedEmployeeId == null
            ? (billableStaff.isNotEmpty ? billableStaff.first : null)
            : _firstOrNull(
              billableStaff.where((e) => e.id == _selectedEmployeeId),
            );

    if (_selectedEmployeeId == null && selectedEmployee != null) {
      _selectedEmployeeId = selectedEmployee.id;
    }

    double subtotal = 0.0;
    for (final id in _selectedServiceIds) {
      final svc = state.services.where((s) => s.id == id);
      if (svc.isNotEmpty) subtotal += _servicePrices[id] ?? svc.first.price;
    }
    for (final entry in _selectedProductQuantities.entries) {
      final prod = state.inventory.where((p) => p.id == entry.key);
      if (prod.isNotEmpty) subtotal += prod.first.price * entry.value;
    }
    // Same whole-rupee maths createBill writes with, so the quote matches
    // the stored bill to the rupee.
    final gstRate = state.settings?.effectiveGstRate ?? 0;
    final totals = computeBillTotals(
      subTotal: subtotal,
      discount: subtotal * (_discountPercent / 100),
      gstRate: gstRate,
    );
    final discountAmount = totals.discount;
    final taxAmount = totals.tax;
    final totalAmount = totals.total;
    final availableCredit = usableCredit(state.clientPackages, _selectedCustomerId, DateTime.now());
    final packageCredit = _usePackage ? math.min(availableCredit, totalAmount) : 0.0;
    final toPayNow = totalAmount - packageCredit;
    // Pay later splits what's left: what's handed over today, and what's owed.
    final payLater = _paymentMethod == 'PENDING' && toPayNow > 0;
    final typedNow = double.tryParse(_partPaymentController.text.trim()) ?? 0;
    final payingNow = payLater ? typedNow.clamp(0, toPayNow).toDouble() : toPayNow;
    final owedLater = toPayNow - payingNow;
    final hasItems = _selectedServiceIds.isNotEmpty || _selectedProductQuantities.isNotEmpty;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: AppTheme.bgSurface,
      child: Column(
        children: [
          Expanded(
            // topCenter: this only caps the width on a laptop. A plain Center
            // would also float a short bill down the page.
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildWhoCard(context, state, selectedCustomer, selectedEmployee, billableStaff),
                      if (availableCredit > 0) ...[
                        const SizedBox(height: 12),
                        _buildPackageCredit(state, availableCredit, packageCredit),
                      ],
                      const SizedBox(height: 12),
                      _buildBillCard(context, state, selectedCustomer),
                      if (hasItems) ...[
                        const SizedBox(height: 12),
                        _buildPaymentCard(toPayNow, discountAmount),
                        const SizedBox(height: 12),
                        _buildTotalsCard(
                          subtotal: subtotal,
                          discountAmount: discountAmount,
                          gstRate: gstRate,
                          taxAmount: taxAmount,
                          totalAmount: totalAmount,
                          packageCredit: packageCredit,
                          payLater: payLater,
                          payingNow: payingNow,
                          owedLater: owedLater,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildDock(context, ref, state, discountAmount, packageCredit, payingNow, owedLater),
        ],
      ),
    );
  }

  /// Client and who did the work, side by side: the two things every bill
  /// needs, one tap each.
  Widget _buildWhoCard(
    BuildContext context,
    AppData state,
    Customer? selectedCustomer,
    EmployeeProfile? selectedEmployee,
    List<EmployeeProfile> billableStaff,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: _whoCell(
                label: 'Client',
                value: selectedCustomer?.name ?? 'Choose a client',
                detail: selectedCustomer != null
                    ? '${selectedCustomer.phone}${selectedCustomer.isVip ? ' • VIP Gold' : ''}'
                    : 'Search, or add someone new',
                missing: selectedCustomer == null,
                onTap: () async {
                  final customer = await showSearchablePicker<Customer>(
                    context: context,
                    title: 'Choose a client',
                    items: state.customers,
                    labelOf: (c) => c.name,
                    subtitleOf: (c) => '${c.phone}${c.isVip ? ' • VIP Gold' : ''}',
                    // A walk-in who isn't on file yet shouldn't mean
                    // abandoning a half-built bill to go and add them.
                    createLabel: 'Add a new client',
                    searchHint: 'Name or mobile number',
                    matches: customerMatchesQuery,
                    onCreate: (ctx) => openAppSubPage<Customer>(
                      ctx,
                      title: 'Add client',
                      subtitle: 'Save their details to start tracking visits',
                      child: AddCustomerPage(branches: state.branches),
                    ),
                  );
                  if (customer != null) {
                    setState(() {
                      _selectedCustomerId = customer.id;
                      _serviceAudience = audienceForGender(customer.gender) ?? _serviceAudience;
                    });
                  }
                },
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle),
            Expanded(
              flex: 4,
              child: _whoCell(
                label: 'Done by',
                value: selectedEmployee?.name ?? 'Choose who did it',
                detail: selectedEmployee != null
                    ? (selectedEmployee.roleTitle.isNotEmpty ? selectedEmployee.roleTitle : 'Stylist')
                    : 'Tap to assign team member',
                missing: selectedEmployee == null,
                onTap: () async {
                  final employee = await showSearchablePicker<EmployeeProfile>(
                    context: context,
                    title: 'Who did the service?',
                    items: billableStaff,
                    labelOf: (e) => e.name,
                    subtitleOf: (e) => e.roleTitle.isNotEmpty ? e.roleTitle : 'Stylist',
                  );
                  if (employee != null) setState(() => _selectedEmployeeId = employee.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whoCell({
    required String label,
    required String value,
    required String detail,
    required bool missing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.slateLight)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: missing ? AppTheme.primaryBlue : AppTheme.slateDark,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight, size: 13, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _openServicePicker(BuildContext context, Customer? client) {
    pushAppRoute(
      context,
      ServicePickerPage(
        clientName: client?.name,
        audience: _serviceAudience,
        onAudienceChanged: (audience) => setState(() => _serviceAudience = audience),
        services: _selectedServiceIds,
        prices: _servicePrices,
        products: _selectedProductQuantities,
        onChanged: () => setState(() {}),
      ),
    );
  }

  /// What's on the bill. The whole menu lives on the pick screen, so this
  /// stays short enough to read at a glance.
  Widget _buildBillCard(BuildContext context, AppData state, Customer? client) {
    final services = state.services.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final products = state.inventory.where((p) => _selectedProductQuantities.containsKey(p.id)).toList();
    final hasItems = services.isNotEmpty || products.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Services',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
            ),
          ),
          for (final svc in services)
            _billLine(
              title: svc.name,
              subtitle: svc.categoryName,
              amount: _servicePrices[svc.id] ?? svc.price,
              onRemove: () => setState(() {
                _selectedServiceIds.remove(svc.id);
                _servicePrices.remove(svc.id);
              }),
              // A price settled on the bill can be settled again.
              onAmountTap: !svc.priceVaries
                  ? null
                  : () async {
                      final price = await askServicePrice(context, svc);
                      if (price != null) setState(() => _servicePrices[svc.id] = price);
                    },
            ),
          for (final prod in products)
            _billLine(
              title: prod.name,
              subtitle: '${_selectedProductQuantities[prod.id]} × ${formatInr(prod.price)}',
              amount: prod.price * _selectedProductQuantities[prod.id]!,
              onRemove: () => setState(() => _selectedProductQuantities.remove(prod.id)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              height: 48,
              child: hasItems
                  ? OutlinedButton.icon(
                      onPressed: () => _openServicePicker(context, client),
                      icon: const Icon(PhosphorIconsBold.plus, size: 16),
                      label: const Text('Add services'),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _openServicePicker(context, client),
                      icon: const Icon(PhosphorIconsBold.plus, size: 16),
                      label: const Text('Add services'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// How the bill adds up, last on the page because everything above it
  /// changes these figures: the lines, the discount and the payment.
  Widget _buildTotalsCard({
    required double subtotal,
    required double discountAmount,
    required double gstRate,
    required double taxAmount,
    required double totalAmount,
    required double packageCredit,
    required bool payLater,
    required double payingNow,
    required double owedLater,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          if (discountAmount > 0 || gstRate > 0)
            _totalLine('Subtotal', formatInr(subtotal)),
          if (discountAmount > 0)
            _totalLine('Discount (${_discountPercent.toStringAsFixed(0)}%)', '-${formatInr(discountAmount)}'),
          // GST is opt-in - no row at all until the owner sets a rate in
          // Settings.
          if (gstRate > 0)
            _totalLine('GST (${gstRate.toStringAsFixed(0)}%)', formatInr(taxAmount)),
          _totalLine('Total Amount', formatInr(totalAmount), strong: true),
          // Calling a total "inclusive of taxes" when GST is switched off (or
          // was never configured) is simply untrue.
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              gstRate > 0 ? 'Inclusive of all salon taxes' : 'No GST applied',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          if (packageCredit > 0 || payLater) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, color: AppTheme.borderSubtle),
            ),
            if (packageCredit > 0)
              _totalLine('Paid from package', '-${formatInr(packageCredit)}'),
            _totalLine('Paying now', formatInr(payingNow), strong: true),
            if (owedLater > 0)
              _totalLine('Still owed', formatInr(owedLater), strong: true, color: AppTheme.accentAmber),
          ],
        ],
      ),
    );
  }

  Widget _billLine({
    required String title,
    String? subtitle,
    required double amount,
    required VoidCallback onRemove,
    VoidCallback? onAmountTap,
  }) {
    final value = Text(
      formatInr(amount),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onAmountTap == null ? AppTheme.slateDark : AppTheme.primaryBlue,
        decoration: onAmountTap == null ? null : TextDecoration.underline,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderSubtle))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onAmountTap == null)
            value
          else
            InkWell(
              onTap: onAmountTap,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: value),
            ),
          IconButton(
            tooltip: 'Remove $title',
            onPressed: onRemove,
            icon: const Icon(PhosphorIconsRegular.x, size: 15, color: AppTheme.slateLight),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, String value, {bool strong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: strong ? 14 : 13,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              color: color ?? (strong ? AppTheme.slateDark : AppTheme.slateLight),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 15 : 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.slateDark,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// How it's paid and any discount. Only shows once there's something to pay
  /// for, so a new bill starts as just a client and a button.
  Widget _buildPaymentCard(double toPayNow, double discountAmount) {
    final percent = _discountPercent.round();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (toPayNow > 0) ...[
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
            ),
            const SizedBox(height: 8),
            Row(
              // CARD is no longer offered - the salon does not take card
              // payments. Bills already stored with paymentMethod 'CARD' keep
              // working everywhere that reads them; this only stops new ones
              // being created.
              children: [
                for (final (i, method) in const ['UPI', 'CASH', 'PENDING'].indexed)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: _choiceChip(
                        label: paymentMethodLabel(method),
                        selected: _paymentMethod == method,
                        onTap: () => setState(() => _paymentMethod = method),
                      ),
                    ),
                  ),
              ],
            ),
            // Part-payment box. Only meaningful for PENDING: the other
            // methods always collect the full amount.
            if (_paymentMethod == 'PENDING') ...[
              const SizedBox(height: 12),
              _buildPartPaymentBox(toPayNow),
            ],
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Discount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                ),
              ),
              Text(
                percent > 0 ? '$percent% (${formatInr(discountAmount)} off)' : 'None',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: percent > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: percent > 0 ? AppTheme.accentGreen : AppTheme.slateLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Any whole percent up to 25: the stepper for the odd figure, the
          // presets for the usual ones.
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepButton(PhosphorIconsBold.minus, 'Less discount',
                        percent <= 0 ? null : () => setState(() => _discountPercent = percent - 1.0)),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                      ),
                    ),
                    _stepButton(PhosphorIconsBold.plus, 'More discount',
                        percent >= 25 ? null : () => setState(() => _discountPercent = percent + 1.0)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              for (final preset in const [5, 10, 15, 20])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _choiceChip(
                      label: '$preset%',
                      selected: percent == preset,
                      onTap: () => setState(() => _discountPercent = percent == preset ? 0 : preset.toDouble()),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 40,
          child: Icon(icon, size: 14, color: onTap == null ? AppTheme.borderStrong : AppTheme.primaryBlue),
        ),
      ),
    );
  }

  Widget _choiceChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryLight : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppTheme.primaryBlue : AppTheme.borderSubtle, width: selected ? 1.5 : 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppTheme.primaryBlue : AppTheme.slateLight,
            ),
          ),
        ),
      ),
    );
  }

  /// What's left to pay and Create bill, docked so they stay in view.
  Widget _buildDock(
    BuildContext context,
    WidgetRef ref,
    AppData state,
    double discountAmount,
    double packageCredit,
    double payingNow,
    double owedLater,
  ) {
    final hasItems = _selectedServiceIds.isNotEmpty || _selectedProductQuantities.isNotEmpty;
    final canSubmit = hasItems && _selectedCustomerId != null && _selectedEmployeeId != null && !_submitting;

    // A greyed-out button alone doesn't say why - name the first thing still
    // missing.
    final missing = _selectedCustomerId == null
        ? 'Choose a client'
        : !hasItems
            ? 'Add a service or product'
            : _selectedEmployeeId == null
                ? 'Choose who did the service'
                : null;
    final count = _selectedServiceIds.length + _selectedProductQuantities.length;
    final caption = !_submitting && missing != null
        ? missing
        : owedLater > 0
            ? 'Paying now, ${formatInr(owedLater)} owed'
            : packageCredit > 0
                ? 'To pay now'
                : '$count item${count == 1 ? '' : 's'}';

    return Container(
      color: AppTheme.primaryBlue,
      // Scaffold.extendBody puts the bottom bar's height here on a phone.
      padding: EdgeInsets.fromLTRB(16, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primarySoft),
                ),
                Text(
                  formatInr(payingNow),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: canSubmit ? () => _submit(context, ref, state, discountAmount, packageCredit) : null,
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(128, 46)),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled) ? AppTheme.primaryDark : Colors.white,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled) ? AppTheme.primarySoft : AppTheme.primaryBlue,
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.primaryBlue),
                  )
                : const Text('Create bill'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    AppData state,
    double discountAmount,
    double packageCredit,
  ) async {
    // Clear messages instead of a null-check crash ("Unexpected null value")
    // when a required pick is missing.
    final missing = _selectedBranchId == null
        ? 'This salon has no branch yet - add one in Settings > Branches.'
        : _selectedEmployeeId == null
            ? 'Choose the attending stylist first.'
            : _selectedCustomerId == null
                ? 'Choose a customer first.'
                : null;
    if (missing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(missing), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final items = [
        ..._selectedServiceIds.map(
          (id) => BillItemInput(
            type: 'SERVICE',
            serviceId: id,
            employeeId: _selectedEmployeeId!,
            quantity: 1,
            unitPrice: _servicePrices[id],
          ),
        ),
        ..._selectedProductQuantities.entries.map(
          (e) => BillItemInput(
            type: 'PRODUCT',
            inventoryItemId: e.key,
            employeeId: _selectedEmployeeId!,
            quantity: e.value,
          ),
        ),
      ];
      final isPending = _paymentMethod == 'PENDING';
      final typedNow = double.tryParse(_partPaymentController.text.trim()) ?? 0;
      final bill = await ref
          .read(appDataProvider.notifier)
          .createBill(
            customerId: _selectedCustomerId!,
            branchId: _selectedBranchId!,
            // A part-paid bill records the method the collected portion came
            // in on; only a wholly unpaid one is stored as PENDING.
            paymentMethod:
                isPending && typedNow > 0 ? _partPaymentMethod : _paymentMethod,
            discountAmount: discountAmount,
            items: items,
            // null keeps the ordinary "paid in full" path untouched.
            amountPaidNow: isPending ? typedNow : null,
            packageCredit: packageCredit,
          );

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder:
            (ctx) => AppDialog(
              icon: PhosphorIconsRegular.checkCircle,
              iconColor: AppTheme.accentGreen,
              iconBackground: AppTheme.accentGreenBg,
              title: 'Bill Generated',
              subtitle: bill.invoiceNumber,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                _billDoneMessage(bill),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.slateMedium,
                ),
              ),
                  BillWhatsAppNote(customerId: bill.customerId),
                ],
              ),
              actions: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedServiceIds.clear();
                      _selectedProductQuantities.clear();
                      _servicePrices.clear();
                      _usePackage = true;
                      _partPaymentController.clear();
                      _discountPercent = 0.0;
                      // Land on History rather than bouncing to the dashboard:
                      // the bill that was just written is the top row there, so
                      // the save visibly produced something instead of clearing
                      // the form and leaving the page.
                      _section = _BillingSection.history;
                    });
                  },
                  child: const Text('Done'),
                ),
              ),
            ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _billDoneMessage(Bill bill) {
    final credit = bill.packageAmount;
    final till = bill.amountPaid - credit;
    final parts = [
      'Total: ${formatInr(bill.finalAmount)}.',
      if (credit > 0) '${formatInr(credit)} from package credit.',
      if (till > 0)
        'Collected ${formatInr(till)} via ${paymentMethodLabel(bill.amountDue > 0 ? _partPaymentMethod : bill.paymentMethod)}.',
      if (bill.amountDue > 0) '${formatInr(bill.amountDue)} still owed - it is listed in Clients › Dues.',
    ];
    return parts.join(' ');
  }

  /// The client's credit and the switch to spend it. On by default: someone
  /// who bought a package expects it to be used.
  Widget _buildPackageCredit(AppData state, double available, double used) {
    final soonest = usablePackages(state.clientPackages, _selectedCustomerId, DateTime.now()).first;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primarySoft),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.ticket, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatInr(available)} package credit',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                ),
                Text(
                  'Expires ${packageDate(soonest.expiresAt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          Switch(
            value: _usePackage,
            onChanged: (value) => setState(() => _usePackage = value),
          ),
        ],
      ),
    );
  }

  /// Shown under the method chips once "PENDING" is picked: how much (if
  /// anything) is being collected now, and what that leaves outstanding.
  /// Leaving it blank means the whole bill is owed, which is the common case
  /// - so nothing has to be typed for a straightforward "pay next time".
  Widget _buildPartPaymentBox(double totalAmount) {
    final entered = double.tryParse(_partPaymentController.text.trim()) ?? 0;
    final paidNow = entered.clamp(0, totalAmount).toDouble();
    final due = totalAmount - paidNow;
    final overTyped = entered > totalAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.clockCountdown,
                size: 15,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
              const Text(
                'Paying later',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatInr(due)} will be owed',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _partPaymentController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
                fontSize: 13,
              ),
              hintText: 'Paying now (leave blank for nothing)',
              hintStyle: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
              ),
              errorText:
                  overTyped
                      ? 'More than the bill total (${formatInr(totalAmount)})'
                      : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFDE68A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD97706),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (paidNow > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                const Text(
                  'Collected via',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(width: 8),
                for (final m in ['CASH', 'UPI'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _partPaymentMethod = m),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _partPaymentMethod == m
                                  ? const Color(0xFFD97706)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          paymentMethodLabel(m),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                _partPaymentMethod == m
                                    ? Colors.white
                                    : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --- INVENTORY TAB ---

/// Add a service or a product - the Services page header's "Add" opens
/// this choice (see owner_dashboard.dart). The two used to be a pair of
/// big buttons at the top of the page.
void showAddCatalogItemSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'What do you want to add?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
              ),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.scissors, color: AppTheme.primaryBlue),
              title: const Text('Service', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Something clients book - a haircut, a facial'),
              onTap: () {
                Navigator.pop(sheetCtx);
                final categories = ref.read(appDataProvider).valueOrNull?.categories ?? const <ServiceCategory>[];
                showAddServiceDialog(context, ref, categories);
              },
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.package, color: AppTheme.primaryBlue),
              title: const Text('Product', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Something you sell and keep stock of'),
              onTap: () {
                Navigator.pop(sheetCtx);
                showAddProductDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void showAddProductDialog(BuildContext context, WidgetRef ref) {
  final skuController = TextEditingController();
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController(text: '0');
  final thresholdController = TextEditingController(text: '5');

  bool submitting = false;
  showDialog(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setDialogState) => AppDialog(
                icon: PhosphorIconsRegular.package,
                title: 'Add Product',
                subtitle: 'Adds it to the retail catalog and stock ledger.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name first; the SKU is optional and comes after
                    // the essentials - it used to be the first, required
                    // field, and most salons have no SKU codes.
                    TextField(
                      controller: nameController,
                      decoration: appDialogFieldDecoration(
                        label: 'Product Name *',
                        icon: PhosphorIconsRegular.tag,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: appDialogFieldDecoration(
                        label: 'Category *',
                        hint: 'e.g. Hair Care',
                        icon: PhosphorIconsRegular.squaresFour,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: appDialogFieldDecoration(
                        label: 'Selling Price (₹) *',
                        icon: PhosphorIconsRegular.currencyInr,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: appDialogFieldDecoration(
                        label: 'Cost Price (₹) *',
                        icon: PhosphorIconsRegular.receipt,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: skuController,
                      decoration: appDialogFieldDecoration(
                        label: 'SKU / barcode',
                        hint: 'Optional - one is made up if left blank',
                        icon: PhosphorIconsRegular.barcode,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: appDialogFieldDecoration(
                              label: 'Initial Stock',
                              icon: PhosphorIconsRegular.stack,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: thresholdController,
                            keyboardType: TextInputType.number,
                            decoration: appDialogFieldDecoration(
                              label: 'Low Stock Alert',
                              icon: PhosphorIconsRegular.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: AppDialogActions(
                  submitLabel: 'Add Product',
                  submitting: submitting,
                  onCancel: () => Navigator.pop(ctx),
                  onSubmit: () async {
                    final sku = skuController.text.trim();
                    final name = nameController.text.trim();
                    final category = categoryController.text.trim();
                    final price = double.tryParse(priceController.text);
                    final cost = double.tryParse(costController.text);
                    if (name.isEmpty ||
                        category.isEmpty ||
                        price == null ||
                        cost == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Fill in the name, category and both prices.',
                          ),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      await ref
                          .read(appDataProvider.notifier)
                          .addInventoryItem(
                            sku: sku,
                            name: name,
                            category: category,
                            price: price,
                            costPrice: cost,
                            stockCount:
                                int.tryParse(stockController.text) ?? 0,
                            minAlertThreshold:
                                int.tryParse(thresholdController.text) ?? 5,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name added to inventory.'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
        ),
  );
}

/// A service's own WhatsApp come-back gap (SalonService.reminderDays),
/// optional: blank means the salon's general gap from the WhatsApp page.
Widget _serviceReminderField(TextEditingController controller, WidgetRef ref) {
  final general = ref.read(appDataProvider).valueOrNull?.settings?.whatsappReminderDays ?? 21;
  return TextField(
    key: const Key('serviceReminderDays'),
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: appDialogFieldDecoration(
      label: 'Come-back reminder after (days)',
      hint: 'Blank = salon default, $general days',
      icon: PhosphorIconsRegular.clockCounterClockwise,
    ),
  );
}

/// Blank -> null (salon default); otherwise whole days. Range is checked by
/// AppDataNotifier so the message there is the one shown.
int? _parseReminderDays(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null) throw Exception('Reminder days must be a whole number, or left blank');
  return n;
}

/// The service forms' "For" row and category field, shared by Add and Edit.
class _ServiceFiling extends StatelessWidget {
  final String? audience;
  final String? category;
  final ValueChanged<String?> onAudienceChanged;
  final ValueChanged<String> onCategoryChanged;
  final List<ServiceCategory> categories;

  const _ServiceFiling({
    required this.audience,
    required this.category,
    required this.onAudienceChanged,
    required this.onCategoryChanged,
    required this.categories,
  });

  Future<String?> _askCategoryName(BuildContext context) {
    final controller = TextEditingController();
    void done(BuildContext ctx) {
      final name = controller.text.trim();
      if (name.isNotEmpty) Navigator.pop(ctx, name);
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => done(ctx),
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => done(ctx), child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'For',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateMedium),
        ),
        const SizedBox(height: 6),
        AudienceChoice(
          value: audience,
          options: const [(kAudienceGents, 'Gents'), (kAudienceLadies, 'Ladies'), (null, 'Both')],
          onChanged: onAudienceChanged,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showSearchablePicker<String>(
              context: context,
              title: 'Choose a category',
              items: serviceCategoryChoices(audience, categories.map((c) => c.name)),
              labelOf: (c) => c,
              createLabel: 'New category',
              searchHint: 'Search categories',
              onCreate: _askCategoryName,
            );
            if (picked != null) onCategoryChanged(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            isEmpty: category == null,
            decoration: appDialogFieldDecoration(
              label: 'Category *',
              icon: PhosphorIconsRegular.squaresFour,
            ).copyWith(
              suffixIcon: const Icon(PhosphorIconsBold.caretDown, size: 13),
            ),
            child: Text(
              category ?? '',
              style: const TextStyle(fontSize: 14, color: AppTheme.slateDark),
            ),
          ),
        ),
      ],
    );
  }
}

/// The price, or - for a price settled on the bill - the usual prices if
/// there are any. Shared by Add and Edit Service.
class _ServicePriceFields extends StatelessWidget {
  final bool varies;
  final ValueChanged<bool> onVariesChanged;
  final TextEditingController priceController;
  final TextEditingController optionsController;

  const _ServicePriceFields({
    required this.varies,
    required this.onVariesChanged,
    required this.priceController,
    required this.optionsController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (varies)
          TextField(
            controller: optionsController,
            keyboardType: TextInputType.text,
            decoration: appDialogFieldDecoration(
              label: 'Usual prices',
              hint: 'e.g. 2900, 3400, 3900 - or leave blank',
              icon: PhosphorIconsRegular.currencyInr,
            ),
          )
        else
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: appDialogFieldDecoration(
              label: 'Price (₹) *',
              icon: PhosphorIconsRegular.currencyInr,
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: varies,
          onChanged: onVariesChanged,
          title: const Text('Price varies', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Set the price on each bill', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// The category's id, creating it the first time a salon files something
/// under it. Read fresh: the list a form opened with can be out of date.
Future<String> _serviceCategoryId(WidgetRef ref, String name) async {
  final categories = ref.read(appDataProvider).valueOrNull?.categories ?? const <ServiceCategory>[];
  final existing = categories.where((c) => c.name.toLowerCase() == name.toLowerCase());
  if (existing.isNotEmpty) return existing.first.id;
  return (await ref.read(appDataProvider.notifier).addServiceCategory(name)).id;
}

void showAddServiceDialog(
  BuildContext context,
  WidgetRef ref,
  List<ServiceCategory> categories, {
  String? audience,
}) {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final reminderController = TextEditingController();
  final optionsController = TextEditingController();
  String? categoryName;
  String? serviceAudience = audience;
  bool priceVaries = false;
  bool submitting = false;

  showDialog(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setDialogState) => AppDialog(
                icon: PhosphorIconsRegular.scissors,
                title: 'Add Service',
                subtitle:
                    'Adds it to the service menu everyone can bill against.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ServiceFiling(
                      audience: serviceAudience,
                      category: categoryName,
                      categories: categories,
                      onAudienceChanged: (value) => setDialogState(() => serviceAudience = value),
                      onCategoryChanged: (value) => setDialogState(() => categoryName = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: appDialogFieldDecoration(
                        label: 'Service Name *',
                        hint: 'e.g. Haircut',
                        icon: PhosphorIconsRegular.tag,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ServicePriceFields(
                      varies: priceVaries,
                      onVariesChanged: (value) => setDialogState(() => priceVaries = value),
                      priceController: priceController,
                      optionsController: optionsController,
                    ),
                    const SizedBox(height: 4),
                    _serviceReminderField(reminderController, ref),
                  ],
                ),
                actions: AppDialogActions(
                  submitLabel: 'Add Service',
                  submitting: submitting,
                  onCancel: () => Navigator.pop(ctx),
                  onSubmit: () async {
                    final name = nameController.text.trim();
                    final options = priceVaries ? parsePriceOptions(optionsController.text) : const <double>[];
                    final price = priceVaries
                        ? (options.isEmpty ? 0.0 : options.first)
                        : double.tryParse(priceController.text);
                    final category = categoryName;
                    if (name.isEmpty || price == null || category == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'All fields are required with a valid price.',
                          ),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      final reminderDays = _parseReminderDays(reminderController.text);
                      final categoryId = await _serviceCategoryId(ref, category);
                      await ref
                          .read(appDataProvider.notifier)
                          .addService(
                            name: name,
                            price: price,
                            categoryId: categoryId,
                            reminderDays: reminderDays,
                            audience: serviceAudience,
                            priceVaries: priceVaries,
                            priceOptions: options,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name added to the service menu.'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceFirst('Exception: ', '')),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
        ),
  );
}

const String _kProductsEntry = '__products';
const String _kLowStockEntry = '__lowStock';

class OwnerInventoryTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerInventoryTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerInventoryTab> createState() => _OwnerInventoryTabState();
}

class _OwnerInventoryTabState extends State<OwnerInventoryTab> {
  final _stockController = TextEditingController();
  final _searchController = TextEditingController();
  // Which side of the menu is showing: Gents, Ladies, or null for all.
  String? _audience;
  // The category open on the right; null opens the first.
  String? _entry;

  @override
  void dispose() {
    _stockController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _removeButton({required String label, required VoidCallback? onPressed}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(PhosphorIconsRegular.trash, size: 15, color: AppTheme.accentRed),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.accentRed),
        ),
      ),
    );
  }

  /// Asks before taking something out of the catalog, then does it. Returns
  /// whether it was removed, so the edit dialog underneath can close too.
  Future<bool> _confirmRemove(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required Future<void> Function() remove,
  }) async {
    bool submitting = false;
    final removed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.trash,
          iconColor: AppTheme.accentRed,
          iconBackground: AppTheme.accentRedBg,
          title: title,
          child: Text(
            body,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: 'Remove',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx, false),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await remove();
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.accentRed),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
    return removed ?? false;
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, InventoryItem prod) {
    final nameController = TextEditingController(text: prod.name);
    final categoryController = TextEditingController(text: prod.category);
    final priceController = TextEditingController(text: prod.price.toStringAsFixed(0));
    final costController = TextEditingController(text: prod.costPrice.toStringAsFixed(0));
    final alertController = TextEditingController(text: '${prod.minAlertThreshold}');
    bool submitting = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AppDialog(
                  icon: PhosphorIconsRegular.pencilSimple,
                  title: 'Edit Product',
                  subtitle: 'SKU ${prod.sku} - use Update Stock to change the quantity.',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: appDialogFieldDecoration(label: 'Product Name *', icon: PhosphorIconsRegular.tag),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: categoryController,
                        decoration: appDialogFieldDecoration(label: 'Category *', icon: PhosphorIconsRegular.squaresFour),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: appDialogFieldDecoration(label: 'Selling (₹) *', icon: PhosphorIconsRegular.currencyInr),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType: TextInputType.number,
                              decoration: appDialogFieldDecoration(label: 'Cost (₹) *', icon: PhosphorIconsRegular.receipt),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: alertController,
                        keyboardType: TextInputType.number,
                        decoration: appDialogFieldDecoration(
                          label: 'Low Stock Alert',
                          hint: 'Warn when stock falls to this',
                          icon: PhosphorIconsRegular.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _removeButton(
                        label: 'Remove from catalog',
                        onPressed: submitting
                            ? null
                            : () async {
                                final removed = await _confirmRemove(
                                  context,
                                  ref,
                                  title: 'Remove ${prod.name}?',
                                  body: 'It disappears from the catalog and from billing. '
                                      'Past bills and reports still show it.',
                                  remove: () => ref.read(appDataProvider.notifier).removeInventoryItem(prod.id),
                                );
                                if (removed && ctx.mounted) Navigator.pop(ctx);
                              },
                      ),
                    ],
                  ),
                  actions: AppDialogActions(
                    submitLabel: 'Save',
                    submitting: submitting,
                    onCancel: () => Navigator.pop(ctx),
                    onSubmit: () async {
                      final price = double.tryParse(priceController.text.trim());
                      final cost = double.tryParse(costController.text.trim());
                      final alert = int.tryParse(alertController.text.trim());
                      if (price == null || cost == null || alert == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter valid numbers for prices and the alert level'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(appDataProvider.notifier).updateInventoryDetails(
                              prod.id,
                              name: nameController.text,
                              category: categoryController.text,
                              price: price,
                              costPrice: cost,
                              minAlertThreshold: alert,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${nameController.text.trim()} updated.'), backgroundColor: AppTheme.accentGreen),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.accentRed),
                          );
                        }
                      }
                    },
                  ),
                ),
          ),
    );
  }

  void _showEditServiceDialog(BuildContext context, WidgetRef ref, SalonService svc) {
    final nameController = TextEditingController(text: svc.name);
    final priceController = TextEditingController(text: svc.price.toStringAsFixed(0));
    final reminderController = TextEditingController(text: svc.reminderDays?.toString() ?? '');
    final categories = ref.read(appDataProvider).valueOrNull?.categories ?? const <ServiceCategory>[];
    final currentCategory = (svc.categoryName ?? '').trim();
    String? categoryName = currentCategory.isEmpty ? null : currentCategory;
    String? serviceAudience = svc.audience;
    final optionsController = TextEditingController(text: svc.priceOptions.map((p) => p.toStringAsFixed(0)).join(', '));
    bool priceVaries = svc.priceVaries;
    bool submitting = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AppDialog(
                  icon: PhosphorIconsRegular.pencilSimple,
                  title: 'Edit Service',
                  subtitle: 'A new price applies to new bills only - past bills keep the price they were charged.',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ServiceFiling(
                        audience: serviceAudience,
                        category: categoryName,
                        categories: categories,
                        onAudienceChanged: (value) => setDialogState(() => serviceAudience = value),
                        onCategoryChanged: (value) => setDialogState(() => categoryName = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: appDialogFieldDecoration(
                          label: 'Service Name *',
                          icon: PhosphorIconsRegular.tag,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ServicePriceFields(
                        varies: priceVaries,
                        onVariesChanged: (value) => setDialogState(() => priceVaries = value),
                        priceController: priceController,
                        optionsController: optionsController,
                      ),
                      const SizedBox(height: 4),
                      _serviceReminderField(reminderController, ref),
                      const SizedBox(height: 4),
                      _removeButton(
                        label: 'Remove from menu',
                        onPressed: submitting
                            ? null
                            : () async {
                                final removed = await _confirmRemove(
                                  context,
                                  ref,
                                  title: 'Remove ${svc.name}?',
                                  body: 'It disappears from the menu and from billing. '
                                      'Past bills and reports still show it.',
                                  remove: () => ref.read(appDataProvider.notifier).removeService(svc.id),
                                );
                                if (removed && ctx.mounted) Navigator.pop(ctx);
                              },
                      ),
                    ],
                  ),
                  actions: AppDialogActions(
                    submitLabel: 'Save',
                    submitting: submitting,
                    onCancel: () => Navigator.pop(ctx),
                    onSubmit: () async {
                      final options = priceVaries ? parsePriceOptions(optionsController.text) : const <double>[];
                      final price = priceVaries
                          ? (options.isEmpty ? 0.0 : options.first)
                          : double.tryParse(priceController.text.trim());
                      if (price == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid price'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final reminderDays = _parseReminderDays(reminderController.text);
                        final category = categoryName;
                        final categoryId = category == null || category == currentCategory
                            ? null
                            : await _serviceCategoryId(ref, category);
                        await ref.read(appDataProvider.notifier).updateService(
                              svc.id,
                              name: nameController.text,
                              price: price,
                              reminderDays: reminderDays,
                              categoryId: categoryId,
                              audience: serviceAudience,
                              priceVaries: priceVaries,
                              priceOptions: options,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${nameController.text.trim()} updated.'), backgroundColor: AppTheme.accentGreen),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.accentRed),
                          );
                        }
                      }
                    },
                  ),
                ),
          ),
    );
  }

  void _showUpdateStockDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryItem prod,
  ) {
    _stockController.text = prod.stockCount.toString();
    showDialog(
      context: context,
      builder:
          (ctx) => AppDialog(
            icon: PhosphorIconsRegular.stack,
            title: 'Update Stock Level',
            subtitle: prod.name,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKU: ${prod.sku} • Category: ${prod.category}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: appDialogFieldDecoration(
                    label: 'Available Units *',
                    icon: PhosphorIconsRegular.package,
                  ),
                ),
              ],
            ),
            actions: AppDialogActions(
              submitLabel: 'Save Stock',
              onCancel: () => Navigator.pop(ctx),
              onSubmit: () async {
                final newStk = int.tryParse(_stockController.text);
                Navigator.pop(ctx);
                if (newStk != null) {
                  try {
                    await ref
                        .read(appDataProvider.notifier)
                        .updateInventoryStock(prod.id, newStk);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${prod.name} stock set to $newStk units.',
                          ),
                          backgroundColor: AppTheme.accentGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error:
              (err, st) => AppErrorView(
                error: err,
                onRetry: () => ref.read(appDataProvider.notifier).refresh(),
              ),
          data: (state) => _buildContent(context, ref, state),
        );
      },
    );
  }

  // Same shape as the Add services screen: Gents or Ladies, categories down
  // the left, one category on the right. A menu this size can't be one list.
  //
  // No salon name / bell / avatar row here: this page is always embedded
  // under a header that already carries them.
  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final query = _searchController.text.trim().toLowerCase();
    final shown = state.services.where((s) => audiencesOverlap(s.audience, _audience)).toList();
    final groups = groupServices(shown);
    final lowStock = state.inventory.where((p) => p.isLowStock).toList();

    // At the top, as on the pick screen: below every category they're lost.
    final entries = [
      if (state.inventory.isNotEmpty) const MenuRailEntry(_kProductsEntry, 'Products'),
      if (lowStock.isNotEmpty) MenuRailEntry(_kLowStockEntry, 'Low stock', count: lowStock.length, warning: true),
      for (final g in groups) MenuRailEntry(g.name, g.name),
    ];
    // Still opens on services: that's what this page is mostly for.
    final opening = groups.firstOrNull?.name ?? entries.firstOrNull?.id;
    final current = entries.any((e) => e.id == _entry) ? _entry : opening;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AudienceChoice(
                  value: _audience,
                  options: const [(null, 'All'), (kAudienceGents, 'Gents'), (kAudienceLadies, 'Ladies')],
                  onChanged: (audience) => setState(() => _audience = audience),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search services or products',
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(PhosphorIconsRegular.x, size: 16),
                            onPressed: () => setState(_searchController.clear),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          Expanded(
            child: query.isNotEmpty
                ? _buildSearchResults(context, ref, state, shown, query)
                : entries.isEmpty
                    ? const _MenuNote('No services yet - tap Add to build your menu.')
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 116,
                            child: MenuRail(
                              entries: entries,
                              selected: current!,
                              onSelected: (id) => setState(() => _entry = id),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle),
                          Expanded(child: _buildPane(context, ref, state, current, groups, lowStock)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPane(
    BuildContext context,
    WidgetRef ref,
    AppData state,
    String current,
    List<ServiceGroup> groups,
    List<InventoryItem> lowStock,
  ) {
    if (current == _kProductsEntry || current == _kLowStockEntry) {
      final low = current == _kLowStockEntry;
      final products = low ? lowStock : state.inventory;
      return ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _paneTitle(low ? 'Low stock' : 'Products', '${products.length}'),
          for (final prod in products) _productRow(context, ref, prod),
        ],
      );
    }
    final services = groups.firstWhere((g) => g.name == current).services;
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _paneTitle(current, '${services.length}'),
        for (final svc in services) _serviceRow(context, ref, svc),
      ],
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    AppData state,
    List<SalonService> shown,
    String query,
  ) {
    final services = shown
        .where((s) => s.name.toLowerCase().contains(query) || (s.categoryName?.toLowerCase().contains(query) ?? false))
        .toList();
    final products = state.inventory
        .where((p) =>
            p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            p.category.toLowerCase().contains(query))
        .toList();
    if (services.isEmpty && products.isEmpty) {
      return _MenuNote('Nothing matches "${_searchController.text.trim()}"');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final svc in services) _serviceRow(context, ref, svc, showCategory: true),
        for (final prod in products) _productRow(context, ref, prod),
      ],
    );
  }

  Widget _paneTitle(String title, String count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
            ),
          ),
          Text(count, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
        ],
      ),
    );
  }

  /// Tap to change the name, price or category.
  Widget _serviceRow(BuildContext context, WidgetRef ref, SalonService svc, {bool showCategory = false}) {
    final detail = [
      if (showCategory && svc.categoryName != null) svc.categoryName!,
      if (_audience == null || showCategory) serviceAudienceLabel(svc.audience),
    ].join(' • ');
    return InkWell(
      onTap: () => _showEditServiceDialog(context, ref, svc),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderSubtle))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    svc.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                  ),
                  if (detail.isNotEmpty)
                    Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              servicePriceLabel(svc),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretRight, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  /// Tap to edit or remove; the button is the everyday job, so it's one tap.
  Widget _productRow(BuildContext context, WidgetRef ref, InventoryItem prod) {
    final low = prod.isLowStock;
    return InkWell(
      onTap: () => _showEditProductDialog(context, ref, prod),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderSubtle))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                  ),
                  Text(
                    '${formatInr(prod.price)} • ${prod.category}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                  ),
                  Text(
                    low ? '${prod.stockCount} units left' : '${prod.stockCount} units in stock',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: low ? AppTheme.accentAmber : AppTheme.accentGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _showUpdateStockDialog(context, ref, prod),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Update stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuNote extends StatelessWidget {
  final String text;

  const _MenuNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
    );
  }
}

// --- EXPENSES TAB ---

const _expenseCategories = ['RENT', 'UTILITIES', 'SUPPLIES', 'WAGES', 'MISC'];

class OwnerExpensesTab extends StatefulWidget {
  const OwnerExpensesTab({super.key});

  @override
  State<OwnerExpensesTab> createState() => _OwnerExpensesTabState();
}

// Per-category accent, so scanning the list reads as categories rather than
// as a wall of identical red rows.
class _ExpenseStyle {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _ExpenseStyle(this.icon, this.fg, this.bg);
}

const Map<String, _ExpenseStyle> _expenseCategoryStyles = {
  // One soft colour per category (the theme's accent pairs), so the
  // breakdown and history read at a glance - most of these were the same
  // grey-navy before.
  'RENT': _ExpenseStyle(
    PhosphorIconsRegular.buildings,
    AppTheme.accentBlue,
    AppTheme.accentBlueBg,
  ),
  'UTILITIES': _ExpenseStyle(
    PhosphorIconsRegular.lightning,
    AppTheme.accentOrange,
    AppTheme.accentOrangeBg,
  ),
  'SUPPLIES': _ExpenseStyle(
    PhosphorIconsRegular.package,
    AppTheme.accentViolet,
    AppTheme.accentVioletBg,
  ),
  'WAGES': _ExpenseStyle(
    PhosphorIconsRegular.usersThree,
    AppTheme.accentRose,
    AppTheme.accentRoseBg,
  ),
  'MISC': _ExpenseStyle(
    PhosphorIconsRegular.dotsThreeCircle,
    Color(0xFF64748B),
    Color(0xFFF1F5F9),
  ),
};

_ExpenseStyle _styleFor(String category) =>
    _expenseCategoryStyles[category] ?? _expenseCategoryStyles['MISC']!;

/// The Add expense dialog. Top-level so the Expenses page header's "Add"
/// button can open it (see the Expenses entry in owner_dashboard.dart).
void showAddExpenseDialog(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  String category = 'MISC';
  bool submitting = false;

  showDialog(
    context: context,
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setDialogState) => AppDialog(
                icon: PhosphorIconsRegular.receipt,
                iconColor: AppTheme.accentAmber,
                iconBackground: AppTheme.accentAmberBg,
                title: 'Record Expense',
                subtitle: 'Logged against today.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: appDialogFieldDecoration(
                        label: 'Category',
                        icon: PhosphorIconsRegular.tag,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                      elevation: 3,
                      items: [
                        for (final cat in _expenseCategories)
                          DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  _styleFor(cat).icon,
                                  size: 15,
                                  color: _styleFor(cat).fg,
                                ),
                                const SizedBox(width: 8),
                                Text(expenseCategoryLabel(cat)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: appDialogFieldDecoration(
                        label: 'Title *',
                        hint: 'e.g. Tea and snacks',
                        icon: PhosphorIconsRegular.textT,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: appDialogFieldDecoration(
                        label: 'Amount (₹) *',
                        hint: 'e.g. 150',
                        icon: PhosphorIconsRegular.currencyInr,
                      ),
                    ),
                  ],
                ),
                actions: AppDialogActions(
                  submitLabel: 'Log Expense',
                  submitting: submitting,
                  onCancel: () => Navigator.pop(ctx),
                  onSubmit: () async {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add a title.'),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid amount.'),
                          backgroundColor: AppTheme.accentRed,
                        ),
                      );
                      return;
                    }
                    setDialogState(() => submitting = true);
                    try {
                      await ref
                          .read(expensesProvider.notifier)
                          .add(
                            title: title,
                            amount: amount,
                            category: category,
                            date:
                                DateTime.now()
                                    .toIso8601String()
                                    .split('T')
                                    .first,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Logged $title (${formatInr(amount)}).',
                            ),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => submitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
        ),
  );
}

class _OwnerExpensesTabState extends State<OwnerExpensesTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Its own provider, not AppData: expenses are fetched when this
        // screen opens rather than on every sign-in - see
        // data/expenses_provider.dart.
        final asyncData = ref.watch(expensesProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error:
              (err, st) => AppErrorView(
                error: err,
                onRetry: () => ref.read(expensesProvider.notifier).refresh(),
              ),
          data: (expenses) => _buildBody(context, ref, expenses),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Expense> expenses,
  ) {
    final now = DateTime.now();
    final catSums = <String, double>{};
    double totalExpense = 0;
    double monthExpense = 0;
    for (final exp in expenses) {
      catSums[exp.category] = (catSums[exp.category] ?? 0) + exp.amount;
      totalExpense += exp.amount;
      final d = exp.date;
      if (d != null && d.month == now.month && d.year == now.year)
        monthExpense += exp.amount;
    }

    final visible =
        _filter == 'All'
            ? expenses
            : expenses.where((e) => e.category == _filter).toList();
    final topCategory =
        catSums.entries.isEmpty
            ? null
            : catSums.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 680,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (Add expense is in the page header now - it sat on a row of
                // its own here, pushing the summary down.)

                // Spend summary - a white card with the accent line, the same
                // shape as Home's revenue card. It was a solid dark-navy
                // block, the heaviest thing in the app, for a page you visit
                // a few times a month.
                Container(
                  padding: const EdgeInsets.all(18),
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
                            decoration: BoxDecoration(
                              color: AppTheme.accentOrangeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.wallet,
                              color: AppTheme.accentOrange,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Total spend',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.slateLight,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${expenses.length} ${expenses.length == 1 ? 'entry' : 'entries'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        formatInr(totalExpense),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slateDark,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _heroStat(
                            'This month',
                            formatInr(monthExpense),
                          ),
                          const SizedBox(width: 10),
                          _heroStat(
                            'Top category',
                            topCategory == null ? '-' : expenseCategoryLabel(topCategory.key),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Breakdown and filters only once something is logged - before
                // that they were five rows of "₹0 0%" and chips that filtered
                // nothing.
                if (expenses.isNotEmpty) ...[
                const Text(
                  'By category',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      // Only categories with spend - four "₹0 0%" rows said
                      // nothing.
                      for (final (i, cat) in _expenseCategories
                          .where((c) => (catSums[c] ?? 0) > 0)
                          .indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _categoryRow(cat, catSums[cat] ?? 0, totalExpense),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', expenses.length),
                      // Only categories that have entries - "Rent (0)" chips
                      // filtered to nothing.
                      for (final cat in _expenseCategories.where(
                        (c) => expenses.any((e) => e.category == c),
                      )) ...[
                        const SizedBox(width: 8),
                        _filterChip(
                          cat,
                          expenses.where((e) => e.category == cat).length,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${visible.length} entr${visible.length == 1 ? 'y' : 'ies'}'
                      '${_filter == 'All' ? '' : ' in $_filter'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  Container(
                    // Full width - it used to shrink to its text and sit
                    // off to one side.
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.receipt,
                          size: 34,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _filter == 'All'
                              ? 'No expenses logged yet.'
                              : 'Nothing logged under $_filter.',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tap Add at the top to record rent, bills or supplies.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Grouped by month with a subtotal on each header. A flat
                  // reverse-chronological list answers "what did we spend on"
                  // but not "what did we spend in August", which is the
                  // question an expense history exists for - and with a few
                  // hundred rows the month boundaries were invisible.
                  for (final group in _groupByMonth(visible)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.label,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Text(
                            '-${formatInr(group.total)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < group.items.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            _expenseRow(context, ref, group.items[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.slateLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.slateDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryRow(String cat, double sum, double total) {
    final style = _styleFor(cat);
    final ratio = total == 0 ? 0.0 : (sum / total).clamp(0.0, 1.0);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(style.icon, size: 15, color: style.fg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expenseCategoryLabel(cat),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    formatInr(sum),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: style.fg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, int count) {
    final isSelected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2F7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          '${expenseCategoryLabel(label)} ($count)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color:
                isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _expenseRow(BuildContext context, WidgetRef ref, Expense exp) {
    final style = _styleFor(exp.category);
    return InkWell(
      onTap: () => _showExpenseDetail(context, ref, exp),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(style.icon, size: 17, color: style.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exp.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${expenseCategoryLabel(exp.category)} - ${exp.date != null ? _formatDay(exp.date) : '-'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // The note was captured at entry and then never shown
                // anywhere, which made the field feel pointless to fill in.
                if (exp.notes != null && exp.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    exp.notes!.trim(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-${formatInr(exp.amount)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.slateDark,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(PhosphorIconsBold.caretRight, size: 12, color: Color(0xFFCBD5E1)),
        ],
      ),
      ),
    );
  }

  /// One expense in full, with the one destructive action this collection
  /// allows. Deleting is deliberately behind a confirm and a second screen:
  /// the row it starts from is 60px tall in a long list, and an accidental
  /// swipe-delete on a month of petty cash has no undo.
  void _showExpenseDetail(BuildContext context, WidgetRef ref, Expense exp) {
    final style = _styleFor(exp.category);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(style.icon, size: 20, color: style.fg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exp.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${expenseCategoryLabel(exp.category)} · ${exp.date != null ? _formatDay(exp.date) : 'No date'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${formatInr(exp.amount)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slateDark,
                    ),
                  ),
                ],
              ),
              if (exp.notes != null && exp.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Text(
                    exp.notes!.trim(),
                    style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF475467)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDeleteExpense(context, ctx, ref, exp),
                  icon: const Icon(PhosphorIconsRegular.trash, size: 18, color: AppTheme.accentRed),
                  label: const Text(
                    'Delete this expense',
                    style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDCA)),
                    backgroundColor: AppTheme.accentRedBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteExpense(
    BuildContext context,
    BuildContext sheetContext,
    WidgetRef ref,
    Expense exp,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete expense?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
        content: Text(
          '"${exp.title}" (${formatInr(exp.amount)}) will be removed from '
          'the ledger. This cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogCtx);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
              try {
                await ref.read(expensesProvider.notifier).remove(exp.id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${exp.title}".'),
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
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Splits an already-newest-first list into month buckets, preserving that
  /// order. listExpenses() orders by date descending, so one pass is enough -
  /// no sort, and undated rows fall into their own bucket at the end rather
  /// than being dropped from the history entirely.
  List<_ExpenseMonth> _groupByMonth(List<Expense> expenses) {
    final groups = <String, _ExpenseMonth>{};
    final order = <String>[];
    for (final e in expenses) {
      final d = e.date;
      final key = d == null ? 'undated' : '${d.year}-${d.month}';
      final group = groups.putIfAbsent(key, () {
        order.add(key);
        return _ExpenseMonth(
          label: d == null ? 'NO DATE' : '${_kExpenseMonths[d.month - 1]} ${d.year}'.toUpperCase(),
        );
      });
      group.items.add(e);
      group.total += e.amount;
    }
    return [for (final k in order) groups[k]!];
  }
}

const _kExpenseMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// One month of expenses, as the history renders it.
class _ExpenseMonth {
  final String label;
  final List<Expense> items = [];
  double total = 0;

  _ExpenseMonth({required this.label});
}
