import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/bill_math.dart';
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
import '../../../widgets/app_sub_page.dart';
import 'owner_reports_page.dart';
import '../../../data/money.dart';

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;


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
  final Set<String> _selectedServiceIds = {};
  final Map<String, int> _selectedProductQuantities = {};
  final _serviceSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  double _discountPercent = 0.0;
  String _paymentMethod = 'UPI';
  // Set only when _paymentMethod == 'PENDING': how much the client is
  // handing over right now, with the rest becoming a due against them.
  // Empty/0 means they're paying the whole bill later.
  final _partPaymentController = TextEditingController();
  // Method used for the portion collected up front on a PENDING bill.
  String _partPaymentMethod = 'CASH';
  // Products & Retail is a disclosure: collapsed by default so the catalog
  // doesn't push the payment/total section off-screen. Purely local UI
  // state - the list itself comes from the already-loaded AppData snapshot,
  // so expanding it costs no Firestore read.
  bool _productsExpanded = false;
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
    _serviceSearchController.dispose();
    _productSearchController.dispose();
    _partPaymentController.dispose();
    super.dispose();
  }

  void _showAddCustomServiceDialog(
    BuildContext context,
    WidgetRef ref,
    AppData state,
  ) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDlgState) => AppDialog(
                  icon: PhosphorIconsRegular.scissors,
                  title: 'Add Custom Service',
                  subtitle: 'Create a custom one-off or catalog service.',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: appDialogFieldDecoration(
                          label: 'Service Name *',
                          icon: PhosphorIconsRegular.sparkle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: appDialogFieldDecoration(
                          label: 'Price (₹) *',
                          icon: PhosphorIconsRegular.currencyInr,
                        ),
                      ),
                    ],
                  ),
                  actions: AppDialogActions(
                    submitLabel: 'Add Service',
                    submitting: isAdding,
                    onCancel: () => Navigator.pop(ctx),
                    onSubmit: () async {
                      final name = nameCtrl.text.trim();
                      final price =
                          double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      if (name.isEmpty || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter a valid service name and price.',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }
                      setDlgState(() => isAdding = true);
                      try {
                        final catId =
                            state.categories.isNotEmpty
                                ? state.categories.first.id
                                : 'default';
                        await ref
                            .read(appDataProvider.notifier)
                            .addService(
                              name: name,
                              price: price,
                              categoryId: catId,
                            );
                        // Also select this new service automatically once loaded
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Custom service "$name" added!'),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() => isAdding = false);
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
    _selectedBranchId ??=
        state.branches.isNotEmpty ? state.branches.first.id : null;

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
      if (svc.isNotEmpty) subtotal += svc.first.price;
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

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Column(
        children: [
          // 2. Scrollable Content Area
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 680,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch Selector if salon has multiple branches
                      if (state.branches.length > 1) ...[
                        Row(
                          children: [
                            const Text(
                              'Branch:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items:
                                    state.branches
                                        .map(
                                          (b) => DropdownMenuItem(
                                            value: b.id,
                                            child: Text(
                                              b.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E3A5F),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) =>
                                        setState(() => _selectedBranchId = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Customer Selection Card
                      InkWell(
                        onTap: () async {
                          final customer = await showSearchablePicker<Customer>(
                            context: context,
                            title: 'Choose a client',
                            items: state.customers,
                            labelOf: (c) => c.name,
                            subtitleOf:
                                (c) =>
                                    '${c.phone}${c.isVip ? ' • VIP Gold' : ''}',
                            // A walk-in who isn't on file yet shouldn't mean
                            // abandoning a half-built bill to go and add them.
                            createLabel: 'Add a new client',
                            searchHint: 'Name or mobile number',
                            matches: customerMatchesQuery,
                            onCreate:
                                (ctx) => openAppSubPage<Customer>(
                                  ctx,
                                  title: 'Add client',
                                  subtitle:
                                      'Save their details to start tracking visits',
                                  child: AddCustomerPage(
                                    branches: state.branches,
                                  ),
                                ),
                          );
                          if (customer != null)
                            setState(() => _selectedCustomerId = customer.id);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.user,
                                  color: Color(0xFF1E3A5F),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CLIENT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedCustomer != null
                                          ? selectedCustomer.name
                                          : 'Choose a client',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            selectedCustomer != null
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF94A3B8),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedCustomer != null
                                          ? '${selectedCustomer.phone}${selectedCustomer.isVip ? ' • VIP Gold' : ''}'
                                          : 'Search, or add someone new',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            selectedCustomer != null
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                PhosphorIconsBold.caretRight,
                                color: Color(0xFF94A3B8),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Attending Stylist Card
                      InkWell(
                        onTap: () async {
                          final employee =
                              await showSearchablePicker<EmployeeProfile>(
                                context: context,
                                title: 'Who did the service?',
                                items: billableStaff,
                                labelOf: (e) => e.name,
                                subtitleOf:
                                    (e) =>
                                        e.roleTitle.isNotEmpty
                                            ? e.roleTitle
                                            : 'Stylist',
                              );
                          if (employee != null)
                            setState(() => _selectedEmployeeId = employee.id);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  PhosphorIconsFill.scissors,
                                  color: Color(0xFFD97706),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DONE BY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedEmployee != null
                                          ? selectedEmployee.name
                                          : 'Choose who did it',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            selectedEmployee != null
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF94A3B8),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedEmployee != null
                                          ? (selectedEmployee
                                                  .roleTitle
                                                  .isNotEmpty
                                              ? selectedEmployee.roleTitle
                                              : 'Senior Creative Director')
                                          : 'Tap to assign team member',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            selectedEmployee != null
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                PhosphorIconsBold.caretDown,
                                color: Color(0xFF94A3B8),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Services Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Services',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          InkWell(
                            onTap:
                                () => _showAddCustomServiceDialog(
                                  context,
                                  ref,
                                  state,
                                ),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Text(
                                '+ New service',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (state.services.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text(
                              'No services yet. Add your menu under Menu > Services, or tap + New service.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        ...state.services.map((svc) {
                          final isChecked = _selectedServiceIds.contains(
                            svc.id,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _selectedServiceIds.remove(svc.id);
                                  } else {
                                    _selectedServiceIds.add(svc.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        isChecked
                                            ? const Color(0xFF1E3A5F)
                                            : const Color(0xFFE2E8F0),
                                    width: isChecked ? 1.5 : 1,
                                  ),
                                  boxShadow:
                                      isChecked
                                          ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF4F46E5,
                                              ).withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            svc.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            svc.categoryName != null
                                                ? '${svc.categoryName} • ${formatInr(svc.price)}'
                                                : formatInr(svc.price),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color:
                                            isChecked
                                                ? const Color(0xFF1E3A5F)
                                                : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color:
                                              isChecked
                                                  ? const Color(0xFF1E3A5F)
                                                  : const Color(0xFFCBD5E1),
                                          width: 1.6,
                                        ),
                                      ),
                                      child:
                                          isChecked
                                              ? const Icon(
                                                PhosphorIconsBold.check,
                                                color: Colors.white,
                                                size: 13,
                                              )
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),

                      // Products & Retail Section - a collapsed disclosure.
                      // The whole catalog is only built when it's open; the
                      // header keeps showing how many lines are already on
                      // the bill so nothing added is silently hidden.
                      InkWell(
                        onTap:
                            () => setState(
                              () => _productsExpanded = !_productsExpanded,
                            ),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Text(
                                'Products',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (_selectedProductQuantities.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2F7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFC3D0E2),
                                    ),
                                  ),
                                  child: Text(
                                    '${_selectedProductQuantities.length} added',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),

                              AnimatedRotation(
                                turns: _productsExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                child: const Icon(
                                  PhosphorIconsBold.caretDown,
                                  size: 15,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_productsExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            state.inventory.isEmpty
                                ? 'No products currently registered in catalog.'
                                : 'Tap to browse ${state.inventory.length} product${state.inventory.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      if (_productsExpanded) ...[
                        const SizedBox(height: 10),
                        if (state.inventory.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'No products currently registered in catalog.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          ...state.inventory.map((prod) {
                            final qty =
                                _selectedProductQuantities[prod.id] ?? 0;
                            final isLow = prod.stockCount <= 5;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      qty > 0
                                          ? const Color(0xFF1E3A5F)
                                          : const Color(0xFFE2E8F0),
                                  width: qty > 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2F7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      PhosphorIconsFill.drop,
                                      color: Color(0xFF1E3A5F),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Text(
                                              formatInr(prod.price),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isLow
                                                        ? const Color(
                                                          0xFFFEF3C7,
                                                        )
                                                        : const Color(
                                                          0xFFDCFCE7,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isLow
                                                    ? '${prod.stockCount} LEFT'
                                                    : '${prod.stockCount} IN STOCK',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      isLow
                                                          ? const Color(
                                                            0xFFD97706,
                                                          )
                                                          : const Color(
                                                            0xFF16A34A,
                                                          ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (qty == 0)
                                    InkWell(
                                      onTap: () {
                                        if (prod.stockCount > 0) {
                                          setState(
                                            () =>
                                                _selectedProductQuantities[prod
                                                        .id] =
                                                    1,
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              PhosphorIconsBold.plus,
                                              size: 12,
                                              color: Color(0xFF334155),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Add',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2F7),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFC3D0E2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              PhosphorIconsBold.minus,
                                              size: 14,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (qty <= 1) {
                                                  _selectedProductQuantities
                                                      .remove(prod.id);
                                                } else {
                                                  _selectedProductQuantities[prod
                                                          .id] =
                                                      qty - 1;
                                                }
                                              });
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              '$qty',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1E3A5F),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              PhosphorIconsBold.plus,
                                              size: 14,
                                              color: Color(0xFF1E3A5F),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.all(4),
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                            onPressed:
                                                qty >= prod.stockCount
                                                    ? null
                                                    : () {
                                                      setState(
                                                        () =>
                                                            _selectedProductQuantities[prod
                                                                    .id] =
                                                                qty + 1,
                                                      );
                                                    },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                      const SizedBox(height: 20),

                      // Discount Applied Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      PhosphorIconsBold.tag,
                                      size: 16,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Discount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _discountPercent > 0
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _discountPercent > 0
                                        ? '${_discountPercent.toStringAsFixed(0)}% VIP Salon Promo'
                                        : 'None',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          _discountPercent > 0
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  '0%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF1E3A5F),
                                      inactiveTrackColor: const Color(
                                        0xFFE2E8F0,
                                      ),
                                      thumbColor: const Color(0xFF1E3A5F),
                                      overlayColor: const Color(
                                        0xFF4F46E5,
                                      ).withValues(alpha: 0.12),
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _discountPercent,
                                      min: 0,
                                      max: 25,
                                      divisions: 25,
                                      onChanged:
                                          (val) => setState(
                                            () => _discountPercent = val,
                                          ),
                                    ),
                                  ),
                                ),
                                const Text(
                                  '25%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            if (_discountPercent > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2F7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_discountPercent.toStringAsFixed(0)}% (${formatInr(discountAmount)} off)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Payment Method Selector
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        // CARD is no longer offered - the salon does not take
                        // card payments. Bills already stored with
                        // paymentMethod 'CARD' keep working everywhere that
                        // reads them; this only stops new ones being created.
                        children:
                            ['UPI', 'CASH', 'PENDING'].map((method) {
                              final isSel = _paymentMethod == method;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: InkWell(
                                    onTap:
                                        () => setState(
                                          () => _paymentMethod = method,
                                        ),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSel
                                                ? (method == 'PENDING'
                                                    ? const Color(0xFFFFFBEB)
                                                    : const Color(0xFFEEF2F7))
                                                : Colors.white,
                                        border: Border.all(
                                          color:
                                              isSel
                                                  ? (method == 'PENDING'
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF1E3A5F))
                                                  : const Color(0xFFE2E8F0),
                                          width: isSel ? 1.6 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          paymentMethodLabel(method),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                isSel
                                                    ? (method == 'PENDING'
                                                        ? const Color(
                                                          0xFFB45309,
                                                        )
                                                        : const Color(
                                                          0xFF4F46E5,
                                                        ))
                                                    : const Color(0xFF64748B),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                      // Part-payment box. Only meaningful for PENDING: the
                      // three real methods always collect the full amount.
                      if (_paymentMethod == 'PENDING') ...[
                        const SizedBox(height: 12),
                        _buildPartPaymentBox(totalAmount),
                      ],
                      const SizedBox(height: 24),

                      // Bill Summary Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Subtotal (${_selectedServiceIds.length} service${_selectedServiceIds.length == 1 ? '' : 's'}'
                                    '${_selectedProductQuantities.isEmpty ? '' : ' + ${_selectedProductQuantities.length} product${_selectedProductQuantities.length == 1 ? '' : 's'}'})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatInr(subtotal),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            if (discountAmount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Discount (${_discountPercent.toStringAsFixed(0)}%) ',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2F7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'PROMO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '-${formatInr(discountAmount)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // GST is opt-in - no row at all until the owner
                            // sets a rate in Settings.
                            if (gstRate > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'GST (${gstRate.toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    formatInr(taxAmount),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Calling a total "inclusive of taxes"
                                      // when GST is switched off (or was
                                      // never configured) is simply untrue on
                                      // the invoice - the employee-side
                                      // summary already worded this the
                                      // honest way.
                                      Text(
                                        gstRate > 0
                                            ? 'Inclusive of all salon taxes'
                                            : 'No GST applied',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatInr(totalAmount),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E3A5F),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Generate Invoice & Pay Button
                      Builder(
                        builder: (context) {
                          final canSubmit =
                              (_selectedServiceIds.isNotEmpty ||
                                  _selectedProductQuantities.isNotEmpty) &&
                              _selectedCustomerId != null &&
                              _selectedEmployeeId != null &&
                              !_submitting;

                          // A greyed-out button alone doesn't say why - name
                          // the first thing still missing underneath it.
                          final missing = _selectedCustomerId == null
                              ? 'Choose a client to create the bill'
                              : (_selectedServiceIds.isEmpty &&
                                      _selectedProductQuantities.isEmpty)
                                  ? 'Add a service or product'
                                  : _selectedEmployeeId == null
                                      ? 'Choose who did the service'
                                      : null;

                          return Column(
                            children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color:
                                    canSubmit
                                        ? AppTheme.primaryBlue
                                        : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    canSubmit
                                        ? () => _submit(
                                          context,
                                          ref,
                                          state,
                                          discountAmount,
                                        )
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child:
                                    _submitting
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              PhosphorIconsBold.receipt,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Create bill',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                              if (!_submitting && missing != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  missing,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.slateLight,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),

                      // Bottom clearance so floating navbar never overlaps
                      const SizedBox(
                        height: 88,
                      ), // clearance for the floating nav bar
                    ],
                  ),
                ),
              ),
            ),
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
                bill.amountDue > 0
                    ? 'Total: ${formatInr(bill.finalAmount)}. '
                        '${bill.amountPaid > 0 ? 'Collected ${formatInr(bill.amountPaid)} via ${paymentMethodLabel(_partPaymentMethod)}. ' : ''}'
                        '${formatInr(bill.amountDue)} still owed - it is listed in Clients › Dues.'
                    : 'Total: ${formatInr(bill.finalAmount)} via ${paymentMethodLabel(bill.paymentMethod)}.',
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
              const Spacer(),
              Text(
                '${formatInr(due)} will be owed',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
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
            Row(
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

void showAddServiceDialog(
  BuildContext context,
  WidgetRef ref,
  List<ServiceCategory> categories,
) {
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final categoryController = TextEditingController();
  final reminderController = TextEditingController();
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
                    TextField(
                      controller: nameController,
                      decoration: appDialogFieldDecoration(
                        label: 'Service Name *',
                        hint: 'e.g. Haircut',
                        icon: PhosphorIconsRegular.tag,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: appDialogFieldDecoration(
                        label: 'Price (₹) *',
                        icon: PhosphorIconsRegular.currencyInr,
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
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              categories
                                  .map(
                                    (c) => ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        c.name,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed:
                                          () =>
                                              categoryController.text =
                                                  c.name,
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _serviceReminderField(reminderController, ref),
                  ],
                ),
                actions: AppDialogActions(
                  submitLabel: 'Add Service',
                  submitting: submitting,
                  onCancel: () => Navigator.pop(ctx),
                  onSubmit: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text);
                    final categoryName = categoryController.text.trim();
                    if (name.isEmpty ||
                        price == null ||
                        categoryName.isEmpty) {
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
                      final existing = categories.where(
                        (c) =>
                            c.name.toLowerCase() ==
                            categoryName.toLowerCase(),
                      );
                      final categoryId =
                          existing.isNotEmpty
                              ? existing.first.id
                              : (await ref
                                  .read(appDataProvider.notifier)
                                  .addServiceCategory(categoryName)).id;
                      await ref
                          .read(appDataProvider.notifier)
                          .addService(
                            name: name,
                            price: price,
                            categoryId: categoryId,
                            reminderDays: reminderDays,
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

class OwnerInventoryTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerInventoryTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerInventoryTab> createState() => _OwnerInventoryTabState();
}

class _OwnerInventoryTabState extends State<OwnerInventoryTab> {
  final _stockController = TextEditingController();
  final _searchController = TextEditingController();
  String _activeFilter = 'All'; // 'All', 'Services', 'Products', 'Low Stock'

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
                      TextField(
                        controller: nameController,
                        decoration: appDialogFieldDecoration(
                          label: 'Service Name *',
                          icon: PhosphorIconsRegular.tag,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: appDialogFieldDecoration(
                          label: 'Price (₹) *',
                          icon: PhosphorIconsRegular.currencyInr,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      final price = double.tryParse(priceController.text.trim());
                      if (price == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid price'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(appDataProvider.notifier).updateService(
                              svc.id,
                              name: nameController.text,
                              price: price,
                              reminderDays: _parseReminderDays(reminderController.text),
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

  /// Icon by kind of service, colour by category - so a category reads as
  /// one colour down the menu instead of every row being the same tile.
  (Color bg, Color fg, IconData icon) _iconForService(SalonService svc) {
    final (_, _, icon) = _iconForServiceKind(svc);
    final (bg, fg) = AppTheme.avatarColorsFor(svc.categoryName ?? svc.name);
    return (bg, fg, icon);
  }

  (Color bg, Color fg, IconData icon) _iconForServiceKind(SalonService svc) {
    final lower = '${svc.name} ${svc.categoryName ?? ''}'.toLowerCase();
    if (lower.contains('cut') ||
        lower.contains('hair') ||
        lower.contains('trim')) {
      return (
        const Color(0xFFEEF2F7),
        const Color(0xFF1E3A5F),
        PhosphorIconsBold.scissors,
      );
    } else if (lower.contains('beard') ||
        lower.contains('shave') ||
        lower.contains('groom')) {
      return (
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
        PhosphorIconsBold.userCircle,
      );
    } else if (lower.contains('spa') ||
        lower.contains('wash') ||
        lower.contains('oil') ||
        lower.contains('massage')) {
      return (
        const Color(0xFFF1F4F8),
        const Color(0xFF2F4E79),
        PhosphorIconsBold.drop,
      );
    } else if (lower.contains('mani') ||
        lower.contains('pedi') ||
        lower.contains('nail')) {
      return (
        const Color(0xFFF1F4F8),
        const Color(0xFF3E5F8A),
        PhosphorIconsBold.sparkle,
      );
    }
    return (
      const Color(0xFFF3E8FF),
      const Color(0xFF9333EA),
      PhosphorIconsBold.sparkle,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value;
    return InkWell(
      onTap: () => setState(() => _activeFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        // Light tint when selected - the same chip as Clients, Team and
        // bill history.
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFC3D0E2) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryBlue : const Color(0xFF475467),
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
          data: (state) => _buildContent(context, ref, state),
        );
      },
    );
  }

  // No salon name / bell / avatar row here any more: this page is always
  // embedded under a header that already carries them, either as a drawer
  // destination or as the "Services & Pricing" section of Billing's
  // settings. Drawing its own would show the salon name twice.
  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final q = _searchController.text.toLowerCase().trim();

    final filteredServices =
        state.services.where((s) {
          if (q.isEmpty) return true;
          return s.name.toLowerCase().contains(q) ||
              (s.categoryName?.toLowerCase().contains(q) ?? false);
        }).toList();

    final filteredProducts =
        state.inventory.where((p) {
          if (_activeFilter == 'Low Stock' && !p.isLowStock) return false;
          if (q.isEmpty) return true;
          return p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q);
        }).toList();

    final showServices = _activeFilter == 'All' || _activeFilter == 'Services';
    final showProducts =
        _activeFilter == 'All' ||
        _activeFilter == 'Products' ||
        _activeFilter == 'Low Stock';

    return Container(
      color: const Color(0xFFF8F9FC),
      // topCenter, not Center: this only caps the content width on desktop.
      // A plain Center also centres vertically, so as soon as a filter left
      // the list short - Low Stock with nothing low, say - the whole page
      // collapsed into the middle of the viewport with the action buttons
      // floating halfway down.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 680,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (Add service / Add product moved into the page header's
                // "Add" button.)

                // 4. Search Bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search services or products',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  PhosphorIconsBold.x,
                                  size: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Services (${state.services.length})',
                        'Services',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Products (${state.inventory.length})',
                        'Products',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip('Low Stock', 'Low Stock'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 6. Card 1: Service Menu
                if (showServices) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Services',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'What clients can book',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: const [
                                Icon(
                                  PhosphorIconsBold.arrowsDownUp,
                                  size: 13,
                                  color: Color(0xFF1E3A5F),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Reorder',
                                  style: TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Service List Items
                        if (filteredServices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                // "matching your search" only when there is
                                // one - a new salon with an empty menu used
                                // to be told its (empty) search found nothing.
                                state.services.isEmpty
                                    ? 'No services yet - tap + Add Service to build your menu.'
                                    : 'No services match your search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredServices.map((svc) {
                            final (bg, fg, icon) = _iconForService(svc);
                            return InkWell(
                              // Tap to change the name or price - there was
                              // no way to edit a service once added.
                              onTap: () => _showEditServiceDialog(context, ref, svc),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                              padding: const EdgeInsets.only(bottom: 14.0),
                              child: Row(
                                children: [
                                  // Squircle Icon
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(icon, color: fg, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Title and Category
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          svc.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          svc.categoryName ?? 'Styling',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Price
                                  Text(
                                    formatInr(svc.price),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A5F),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    PhosphorIconsRegular.pencilSimple,
                                    size: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 7. Card 2: Product Catalog
                if (showProducts) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Products',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Sold over the counter',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            // (The "Filter Low Stock" button that sat here duplicated the
                            // Low Stock chip above, so it's gone.)
                            const SizedBox.shrink(),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Products List
                        if (filteredProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text(
                                state.inventory.isEmpty
                                    ? 'No products yet - tap + Add Product if you sell retail items.'
                                    : 'No products match this filter.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredProducts.map((prod) {
                            final isLow = prod.isLowStock;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.avatarColorsFor(prod.category).$1,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      PhosphorIconsBold.package,
                                      size: 19,
                                      color: AppTheme.avatarColorsFor(prod.category).$2,
                                    ),
                                  ),
                                  // Product Info - tap to edit or remove
                                  Expanded(
                                    child: InkWell(
                                    onTap: () => _showEditProductDialog(context, ref, prod),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          // Price first - it's what staff
                                          // look for; services already show
                                          // theirs, products didn't.
                                          '${formatInr(prod.price)} • ${prod.category}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        // Stock Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isLow
                                                    ? const Color(0xFFFFFBEB)
                                                    : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            isLow
                                                ? '${prod.stockCount} units left'
                                                : '${prod.stockCount} units in stock',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isLow
                                                      ? const Color(0xFFD97706)
                                                      : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Update Stock Button
                                  OutlinedButton(
                                    onPressed:
                                        () => _showUpdateStockDialog(
                                          context,
                                          ref,
                                          prod,
                                        ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFC3D0E2),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Update stock',
                                      style: TextStyle(
                                        color: Color(0xFF1E3A5F),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
