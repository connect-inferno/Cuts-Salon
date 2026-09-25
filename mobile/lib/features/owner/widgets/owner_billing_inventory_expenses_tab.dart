import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/searchable_picker.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_settings_page.dart';
import 'owner_bill_history.dart';
import 'owner_dues_tab.dart';
import 'owner_management_tabs.dart';
import 'owner_tax_settings.dart';

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

String _formatRupees(double amount) {
  final whole = amount.round().toString();
  if (whole.length <= 3) return '₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole.substring(0, whole.length - 3);
  final grouped = rest.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '₹$grouped,$last3';
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '${d.day} ${months[d.month - 1]}, $hour:$minute $period';
}

// --- BILLING TAB ---

enum _BillingSection { newBill, history }

class OwnerBillingTab extends StatefulWidget {
  final String? preselectedCustomerId;

  const OwnerBillingTab({
    super.key,
    this.preselectedCustomerId,
  });

  @override
  State<OwnerBillingTab> createState() => _OwnerBillingTabState();
}

class _OwnerBillingTabState extends State<OwnerBillingTab> {
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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.preselectedCustomerId;
  }

  @override
  void didUpdateWidget(OwnerBillingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preselectedCustomerId != null && widget.preselectedCustomerId != _selectedCustomerId) {
      _selectedCustomerId = widget.preselectedCustomerId;
    }
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _productSearchController.dispose();
    _partPaymentController.dispose();
    super.dispose();
  }

  void _showAddCustomServiceDialog(BuildContext context, WidgetRef ref, AppData state) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AppDialog(
          icon: PhosphorIconsRegular.scissors,
          title: 'Add Custom Service',
          subtitle: 'Create a custom one-off or catalog service.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: appDialogFieldDecoration(label: 'Service Name *', icon: PhosphorIconsRegular.sparkle),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: 'Price (₹) *', icon: PhosphorIconsRegular.currencyInr),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Add Service',
            submitting: isAdding,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid service name and price.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDlgState(() => isAdding = true);
              try {
                final catId = state.categories.isNotEmpty ? state.categories.first.id : 'default';
                await ref.read(appDataProvider.notifier).addService(name: name, price: price, categoryId: catId);
                // Also select this new service automatically once loaded
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Custom service "$name" added!'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                setDlgState(() => isAdding = false);
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildShell(context, ref, state),
        );
      },
    );
  }

  /// Everything billing-related, on one screen.
  ///
  /// Pending Payments, Discount Requests, the GST rate and the price list
  /// were four separate top-level pages, so "why is this total wrong" or
  /// "who still owes us" meant already knowing which of twelve nav entries
  /// held the answer. They are all consequences of billing, so they are
  /// sections of Billing's own settings - switched with the strip at the
  /// top of that screen, not four more places to navigate to.
  void _openBillingSettings(BuildContext context, AppData state) {
    final pendingDiscounts = state.discountRequests.where((r) => r.status == 'PENDING').length;
    final outstanding = state.bills.fold<double>(0, (s, b) => s + b.amountDue);
    final unpaidClients =
        state.bills.where((b) => !b.isFullyPaid).map((b) => b.customerId).toSet().length;

    openAppSettings(
      context,
      title: 'Billing Settings',
      subtitle: 'Everything that feeds into a bill',
      sections: [
        AppSettingsSection(
          icon: PhosphorIconsRegular.percent,
          label: 'Tax',
          description: 'GST is added to every new bill once it is switched on.',
          builder: (_) => const OwnerTaxSettingsPage(),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.tag,
          label: 'Services & Pricing',
          description:
              '${state.services.length} services and ${state.inventory.length} products. These are the prices a bill resolves against.',
          builder: (_) => const OwnerInventoryTab(),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.handCoins,
          label: 'Dues',
          description: outstanding > 0
              ? '${_formatRupees(outstanding)} billed but not collected, across $unpaidClients client${unpaidClients == 1 ? '' : 's'}.'
              : 'Every bill has been collected in full.',
          builder: (_) => const OwnerDuesTab(),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.sealPercent,
          label: 'Discounts',
          description: pendingDiscounts > 0
              ? '$pendingDiscounts staff discount request${pendingDiscounts == 1 ? '' : 's'} waiting on you.'
              : 'No staff discount requests waiting.',
          badgeCount: pendingDiscounts,
          builder: (_) => const OwnerDiscountsTab(),
        ),
      ],
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
    final billedToday = state.bills.where((b) {
      final d = b.createdAt;
      return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    return Container(
      color: AppTheme.bgSurface,
      child: Column(
        children: [
          AppPageHeader(
            title: 'Billing',
            subtitle: billedToday > 0
                ? '$billedToday bill${billedToday == 1 ? '' : 's'} today'
                : 'No bills yet today',
            showDivider: false,
            actions: [
              appSettingsAction(
                tooltip: 'Billing settings',
                badgeCount: state.discountRequests.where((r) => r.status == 'PENDING').length,
                onTap: () => _openBillingSettings(context, state),
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
            child: _section == _BillingSection.history
                ? OwnerBillHistoryView(state: state)
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
          for (final section in _BillingSection.values)
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
                    color: _section == section ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: _section == section
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
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
                        color: _section == section ? AppTheme.primaryBlue : AppTheme.slateLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section == _BillingSection.newBill ? 'New Bill' : 'History',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _section == section ? AppTheme.primaryBlue : AppTheme.slateLight,
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
    _selectedBranchId ??= state.branches.isNotEmpty ? state.branches.first.id : null;

    final selectedCustomer = _selectedCustomerId == null
        ? null
        : _firstOrNull(state.customers.where((c) => c.id == _selectedCustomerId));
    final selectedEmployee = _selectedEmployeeId == null
        ? (state.employees.isNotEmpty ? state.employees.first : null)
        : _firstOrNull(state.employees.where((e) => e.id == _selectedEmployeeId));

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
    final discountAmount = subtotal * (_discountPercent / 100);
    final taxable = subtotal - discountAmount;
    final gstRate = state.settings?.effectiveGstRate ?? 0;
    final taxAmount = taxable * (gstRate / 100);
    final totalAmount = taxable + taxAmount;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Column(
        children: [
          // 2. Scrollable Content Area
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch Selector if salon has multiple branches
                      if (state.branches.length > 1) ...[
                        Row(
                          children: [
                            const Text('Branch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: state.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))))).toList(),
                                onChanged: (val) => setState(() => _selectedBranchId = val),
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
                            title: 'Select Customer',
                            items: state.customers,
                            labelOf: (c) => c.name,
                            subtitleOf: (c) => '${c.phone}${c.isVip ? ' • VIP Gold' : ''}',
                          );
                          if (customer != null) setState(() => _selectedCustomerId = customer.id);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(PhosphorIconsFill.user, color: Color(0xFF4F46E5), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CUSTOMER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedCustomer != null ? selectedCustomer.name : 'Select Customer',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: selectedCustomer != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedCustomer != null
                                          ? '${selectedCustomer.phone}${selectedCustomer.isVip ? ' • VIP Gold' : ''}'
                                          : 'Tap to choose client profile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedCustomer != null ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(PhosphorIconsBold.caretRight, color: Color(0xFF94A3B8), size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Attending Stylist Card
                      InkWell(
                        onTap: () async {
                          final employee = await showSearchablePicker<EmployeeProfile>(
                            context: context,
                            title: 'Select Stylist',
                            items: state.employees,
                            labelOf: (e) => e.name,
                            subtitleOf: (e) => e.roleTitle.isNotEmpty ? e.roleTitle : 'Stylist',
                          );
                          if (employee != null) setState(() => _selectedEmployeeId = employee.id);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                                child: const Icon(PhosphorIconsFill.scissors, color: Color(0xFFD97706), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ATTENDING STYLIST',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedEmployee != null ? selectedEmployee.name : 'Select Stylist',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: selectedEmployee != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedEmployee != null
                                          ? (selectedEmployee.roleTitle.isNotEmpty ? selectedEmployee.roleTitle : 'Senior Creative Director')
                                          : 'Tap to assign team member',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: selectedEmployee != null ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(PhosphorIconsBold.caretDown, color: Color(0xFF94A3B8), size: 16),
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          InkWell(
                            onTap: () => _showAddCustomServiceDialog(context, ref, state),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                '+ Add Custom',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4F46E5),
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
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Center(child: Text('No services in catalog yet. Tap + Add Custom.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
                        )
                      else
                        ...state.services.map((svc) {
                          final isChecked = _selectedServiceIds.contains(svc.id);
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isChecked ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                    width: isChecked ? 1.5 : 1,
                                  ),
                                  boxShadow: isChecked
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                                ? '${svc.categoryName} • ₹${svc.price.toStringAsFixed(0)}'
                                                : '₹${svc.price.toStringAsFixed(0)}',
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
                                        color: isChecked ? const Color(0xFF4F46E5) : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isChecked ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                          width: 1.6,
                                        ),
                                      ),
                                      child: isChecked
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

                      // Products & Retail Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Products & Retail',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6FFFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFB2F5EA)),
                            ),
                            child: const Text(
                              'Inventory Active',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (state.inventory.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: const Center(child: Text('No products currently registered in catalog.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))),
                        )
                      else
                        ...state.inventory.map((prod) {
                          final qty = _selectedProductQuantities[prod.id] ?? 0;
                          final isLow = prod.stockCount <= 5;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: qty > 0 ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                width: qty > 0 ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    PhosphorIconsFill.drop,
                                    color: Color(0xFF4F46E5),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                            '₹${prod.price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isLow ? '${prod.stockCount} LEFT' : '${prod.stockCount} IN STOCK',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: isLow ? const Color(0xFFD97706) : const Color(0xFF16A34A),
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
                                        setState(() => _selectedProductQuantities[prod.id] = 1);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(PhosphorIconsBold.plus, size: 12, color: Color(0xFF334155)),
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
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(PhosphorIconsBold.minus, size: 14, color: Color(0xFF4F46E5)),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () {
                                            setState(() {
                                              if (qty <= 1) {
                                                _selectedProductQuantities.remove(prod.id);
                                              } else {
                                                _selectedProductQuantities[prod.id] = qty - 1;
                                              }
                                            });
                                          },
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(PhosphorIconsBold.plus, size: 14, color: Color(0xFF4F46E5)),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: qty >= prod.stockCount
                                              ? null
                                              : () {
                                                  setState(() => _selectedProductQuantities[prod.id] = qty + 1);
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
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
                                    Icon(PhosphorIconsBold.tag, size: 16, color: Color(0xFF4F46E5)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Discount Applied',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _discountPercent > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _discountPercent > 0
                                        ? '${_discountPercent.toStringAsFixed(0)}% VIP Salon Promo'
                                        : 'No Discount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _discountPercent > 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('0%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF4F46E5),
                                      inactiveTrackColor: const Color(0xFFE2E8F0),
                                      thumbColor: const Color(0xFF4F46E5),
                                      overlayColor: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                      trackHeight: 6,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                    ),
                                    child: Slider(
                                      value: _discountPercent,
                                      min: 0,
                                      max: 25,
                                      divisions: 25,
                                      onChanged: (val) => setState(() => _discountPercent = val),
                                    ),
                                  ),
                                ),
                                const Text('25%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            if (_discountPercent > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_discountPercent.toStringAsFixed(0)}% (₹${discountAmount.toStringAsFixed(0)} off)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4F46E5),
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
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: ['UPI', 'CASH', 'CARD', 'PENDING'].map((method) {
                          final isSel = _paymentMethod == method;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: InkWell(
                                onTap: () => setState(() => _paymentMethod = method),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? (method == 'PENDING' ? const Color(0xFFFFFBEB) : const Color(0xFFEEF2FF))
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSel
                                          ? (method == 'PENDING' ? const Color(0xFFD97706) : const Color(0xFF4F46E5))
                                          : const Color(0xFFE2E8F0),
                                      width: isSel ? 1.6 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      method == 'PENDING' ? 'LATER' : method,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: isSel
                                            ? (method == 'PENDING' ? const Color(0xFFB45309) : const Color(0xFF4F46E5))
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
                                    'Subtotal (${_selectedServiceIds.length} services + ${_selectedProductQuantities.length} retail)',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${subtotal.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            if (discountAmount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Discount (${_discountPercent.toStringAsFixed(0)}%) ',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'PROMO',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '-₹${discountAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ],
                            // GST is opt-in - no row at all until the owner
                            // sets a rate in Settings.
                            if (gstRate > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'GST (${gstRate.toStringAsFixed(0)}%)',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    '₹${taxAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
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
                                        gstRate > 0 ? 'Inclusive of all salon taxes' : 'No GST applied',
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
                                  '₹${totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4F46E5),
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
                          final canSubmit = (_selectedServiceIds.isNotEmpty || _selectedProductQuantities.isNotEmpty) &&
                              _selectedCustomerId != null &&
                              _selectedEmployeeId != null &&
                              !_submitting;

                          return SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: canSubmit
                                    ? const LinearGradient(
                                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: canSubmit ? null : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: canSubmit
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ElevatedButton(
                                onPressed: canSubmit ? () => _submit(context, ref, state, discountAmount) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(PhosphorIconsBold.receipt, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Generate Invoice & Pay',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Bottom clearance so floating navbar never overlaps
                      const SizedBox(height: 88), // clearance for the floating nav bar
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

  Future<void> _submit(BuildContext context, WidgetRef ref, AppData state, double discountAmount) async {
    setState(() => _submitting = true);
    try {
      final items = [
        ..._selectedServiceIds.map((id) => BillItemInput(type: 'SERVICE', serviceId: id, employeeId: _selectedEmployeeId!, quantity: 1)),
        ..._selectedProductQuantities.entries.map((e) => BillItemInput(type: 'PRODUCT', inventoryItemId: e.key, employeeId: _selectedEmployeeId!, quantity: e.value)),
      ];
      final isPending = _paymentMethod == 'PENDING';
      final typedNow = double.tryParse(_partPaymentController.text.trim()) ?? 0;
      final bill = await ref.read(appDataProvider.notifier).createBill(
            customerId: _selectedCustomerId!,
            branchId: _selectedBranchId!,
            // A part-paid bill records the method the collected portion came
            // in on; only a wholly unpaid one is stored as PENDING.
            paymentMethod: isPending && typedNow > 0 ? _partPaymentMethod : _paymentMethod,
            discountAmount: discountAmount,
            items: items,
            // null keeps the ordinary "paid in full" path untouched.
            amountPaidNow: isPending ? typedNow : null,
          );

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AppDialog(
          icon: PhosphorIconsRegular.checkCircle,
          iconColor: AppTheme.accentGreen,
          iconBackground: AppTheme.accentGreenBg,
          title: 'Bill Generated',
          subtitle: bill.invoiceNumber,
          child: Text(
            bill.amountDue > 0
                ? 'Total: ₹${bill.finalAmount.toStringAsFixed(0)}. '
                    '${bill.amountPaid > 0 ? 'Collected ₹${bill.amountPaid.toStringAsFixed(0)} via $_partPaymentMethod. ' : ''}'
                    '₹${bill.amountDue.toStringAsFixed(0)} outstanding - track it under Pending Payments.'
                : 'Total: ₹${bill.finalAmount.toStringAsFixed(0)} via ${bill.paymentMethod}.',
            style: const TextStyle(fontSize: 14, color: AppTheme.slateMedium),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Shown under the method chips once "LATER" is picked: how much (if
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
              const Icon(PhosphorIconsRegular.clockCountdown, size: 15, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              const Text(
                'Paying later',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
              const Spacer(),
              Text(
                '₹${due.toStringAsFixed(0)} will be owed',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _partPaymentController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              prefixText: '₹ ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E), fontSize: 13),
              hintText: 'Paying now (leave blank for nothing)',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              errorText: overTyped ? 'More than the bill total (₹${totalAmount.toStringAsFixed(0)})' : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
              ),
            ),
          ),
          if (paidNow > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Collected via',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                ),
                const SizedBox(width: 8),
                for (final m in ['CASH', 'UPI', 'CARD'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _partPaymentMethod = m),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _partPaymentMethod == m ? const Color(0xFFD97706) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _partPaymentMethod == m ? Colors.white : const Color(0xFF92400E),
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

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.package,
          title: 'Add Product',
          subtitle: 'Adds it to the retail catalog and stock ledger.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: skuController, decoration: appDialogFieldDecoration(label: 'SKU *', icon: PhosphorIconsRegular.barcode)),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Product Name *', icon: PhosphorIconsRegular.tag)),
              const SizedBox(height: 12),
              TextField(controller: categoryController, decoration: appDialogFieldDecoration(label: 'Category *', hint: 'e.g. Hair Care', icon: PhosphorIconsRegular.squaresFour)),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Selling Price (Rs.) *', icon: PhosphorIconsRegular.currencyInr)),
              const SizedBox(height: 12),
              TextField(controller: costController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Cost Price (Rs.) *', icon: PhosphorIconsRegular.receipt)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: stockController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Initial Stock', icon: PhosphorIconsRegular.stack))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: thresholdController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Low Stock Alert', icon: PhosphorIconsRegular.warning))),
              ]),
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
              if (sku.isEmpty || name.isEmpty || category.isEmpty || price == null || cost == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required with valid numbers.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addInventoryItem(
                      sku: sku,
                      name: name,
                      category: category,
                      price: price,
                      costPrice: cost,
                      stockCount: int.tryParse(stockController.text) ?? 0,
                      minAlertThreshold: int.tryParse(thresholdController.text) ?? 5,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to inventory.'), backgroundColor: AppTheme.accentGreen));
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref, List<ServiceCategory> categories) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final categoryController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.scissors,
          title: 'Add Service',
          subtitle: 'Adds it to the service menu everyone can bill against.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Service Name *', hint: 'e.g. Haircut', icon: PhosphorIconsRegular.tag)),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Price (Rs.) *', icon: PhosphorIconsRegular.currencyInr)),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: appDialogFieldDecoration(label: 'Category *', hint: 'e.g. Hair Care', icon: PhosphorIconsRegular.squaresFour),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories
                        .map((c) => ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(c.name, style: const TextStyle(fontSize: 11)),
                              onPressed: () => categoryController.text = c.name,
                            ))
                        .toList(),
                  ),
                ),
              ],
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
              if (name.isEmpty || price == null || categoryName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required with a valid price.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                final existing = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase());
                final categoryId = existing.isNotEmpty
                    ? existing.first.id
                    : (await ref.read(appDataProvider.notifier).addServiceCategory(categoryName)).id;
                await ref.read(appDataProvider.notifier).addService(name: name, price: price, categoryId: categoryId);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to the service menu.'), backgroundColor: AppTheme.accentGreen));
                }
              } catch (e) {
                setDialogState(() => submitting = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _showUpdateStockDialog(BuildContext context, WidgetRef ref, InventoryItem prod) {
    _stockController.text = prod.stockCount.toString();
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        icon: PhosphorIconsRegular.stack,
        title: 'Update Stock Level',
        subtitle: prod.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${prod.sku} • Category: ${prod.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: appDialogFieldDecoration(label: 'Available Units *', icon: PhosphorIconsRegular.package),
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
                await ref.read(appDataProvider.notifier).updateInventoryStock(prod.id, newStk);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${prod.name} stock set to $newStk units.'), backgroundColor: AppTheme.accentGreen, behavior: SnackBarBehavior.floating),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            }
          },
        ),
      ),
    );
  }

  (Color bg, Color fg, IconData icon) _iconForService(SalonService svc) {
    final lower = '${svc.name} ${svc.categoryName ?? ''}'.toLowerCase();
    if (lower.contains('cut') || lower.contains('hair') || lower.contains('trim')) {
      return (const Color(0xFFEEF2FF), const Color(0xFF4F46E5), PhosphorIconsBold.scissors);
    } else if (lower.contains('beard') || lower.contains('shave') || lower.contains('groom')) {
      return (const Color(0xFFFEF3C7), const Color(0xFFD97706), PhosphorIconsBold.userCircle);
    } else if (lower.contains('spa') || lower.contains('wash') || lower.contains('oil') || lower.contains('massage')) {
      return (const Color(0xFFE0F2FE), const Color(0xFF0284C7), PhosphorIconsBold.drop);
    } else if (lower.contains('mani') || lower.contains('pedi') || lower.contains('nail')) {
      return (const Color(0xFFFCE7F3), const Color(0xFFDB2777), PhosphorIconsBold.sparkle);
    }
    return (const Color(0xFFF3E8FF), const Color(0xFF9333EA), PhosphorIconsBold.sparkle);
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value;
    return InkWell(
      onTap: () => setState(() => _activeFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475467),
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
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
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

    final filteredServices = state.services.where((s) {
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) || (s.categoryName?.toLowerCase().contains(q) ?? false);
    }).toList();

    final filteredProducts = state.inventory.where((p) {
      if (_activeFilter == 'Low Stock' && !p.isLowStock) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
    }).toList();

    final showServices = _activeFilter == 'All' || _activeFilter == 'Services';
    final showProducts = _activeFilter == 'All' || _activeFilter == 'Products' || _activeFilter == 'Low Stock';

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 3. Two Primary Action Buttons (+ Add Service & + Add Product)
                Row(
                  children: [
                    // + Add Service (Outlined Purple)
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddServiceDialog(context, ref, state.categories),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFC7D2FE), width: 1.4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(PhosphorIconsBold.scissors, color: Color(0xFF4F46E5), size: 17),
                              SizedBox(width: 7),
                              Text(
                                '+ Add Service',
                                style: TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // + Add Product (Solid Purple Gradient)
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAddProductDialog(context, ref),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(PhosphorIconsBold.package, color: Colors.white, size: 17),
                              SizedBox(width: 7),
                              Text(
                                '+ Add Product',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Search Bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search services or products...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF94A3B8), size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(PhosphorIconsBold.x, size: 14, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      _buildFilterChip('Services (${state.services.length})', 'Services'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Products (${state.inventory.length})', 'Products'),
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
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                  'Service Menu',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Active salon offerings',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Row(
                              children: const [
                                Icon(PhosphorIconsBold.arrowsDownUp, size: 13, color: Color(0xFF4F46E5)),
                                SizedBox(width: 4),
                                Text(
                                  'Reorder',
                                  style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Service List Items
                        if (filteredServices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text('No services matching your search.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ),
                          )
                        else
                          ...filteredServices.map((svc) {
                            final (bg, fg, icon) = _iconForService(svc);
                            return Padding(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          svc.name,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${svc.categoryName ?? 'Styling'} • Service',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Price
                                  Text(
                                    '₹${svc.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF4F46E5),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
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
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                  'Product Catalog',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Retail stock & inventory',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _activeFilter = _activeFilter == 'Low Stock' ? 'All' : 'Low Stock';
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _activeFilter == 'Low Stock' ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'Filter Low Stock',
                                  style: TextStyle(
                                    color: _activeFilter == 'Low Stock' ? const Color(0xFF4F46E5) : const Color(0xFF475467),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Products List
                        if (filteredProducts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                              child: Text('No products matching filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ),
                          )
                        else
                          ...filteredProducts.map((prod) {
                            final isLow = prod.isLowStock;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                children: [
                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.name,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'SKU: ${prod.sku} • ${prod.category}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        // Stock Chip
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isLow ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isLow ? '${prod.stockCount} units left' : '${prod.stockCount} units in stock',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isLow ? const Color(0xFFD97706) : const Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Update Stock Button
                                  OutlinedButton(
                                    onPressed: () => _showUpdateStockDialog(context, ref, prod),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      'Update Stock',
                                      style: TextStyle(
                                        color: Color(0xFF4F46E5),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
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
  'RENT': _ExpenseStyle(PhosphorIconsRegular.buildings, Color(0xFF4F46E5), Color(0xFFEEF2FF)),
  'UTILITIES': _ExpenseStyle(PhosphorIconsRegular.lightning, Color(0xFFD97706), Color(0xFFFFFBEB)),
  'SUPPLIES': _ExpenseStyle(PhosphorIconsRegular.package, Color(0xFF0D9488), Color(0xFFF0FDFA)),
  'WAGES': _ExpenseStyle(PhosphorIconsRegular.usersThree, Color(0xFF7C3AED), Color(0xFFF5F3FF)),
  'MISC': _ExpenseStyle(PhosphorIconsRegular.dotsThreeCircle, Color(0xFF64748B), Color(0xFFF1F5F9)),
};

_ExpenseStyle _styleFor(String category) =>
    _expenseCategoryStyles[category] ?? _expenseCategoryStyles['MISC']!;

class _OwnerExpensesTabState extends State<OwnerExpensesTab> {
  String _filter = 'All';

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'MISC';
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
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
                initialValue: category,
                decoration: appDialogFieldDecoration(label: 'Category', icon: PhosphorIconsRegular.tag),
                borderRadius: BorderRadius.circular(14),
                dropdownColor: Colors.white,
                elevation: 3,
                items: [
                  for (final cat in _expenseCategories)
                    DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_styleFor(cat).icon, size: 15, color: _styleFor(cat).fg),
                          const SizedBox(width: 8),
                          Text(cat),
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
                decoration: appDialogFieldDecoration(label: 'Title *', hint: 'e.g. Tea and snacks', icon: PhosphorIconsRegular.textT),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appDialogFieldDecoration(label: 'Amount (Rs.) *', hint: 'e.g. 150', icon: PhosphorIconsRegular.currencyInr),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Log Expense',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text.trim());
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please add a title.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addExpense(
                      title: title,
                      amount: amount,
                      category: category,
                      date: DateTime.now().toIso8601String().split('T').first,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logged $title (₹${amount.toStringAsFixed(0)}).'), backgroundColor: AppTheme.accentGreen),
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

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildBody(context, ref, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state) {
    final now = DateTime.now();
    final catSums = <String, double>{};
    double totalExpense = 0;
    double monthExpense = 0;
    for (final exp in state.expenses) {
      catSums[exp.category] = (catSums[exp.category] ?? 0) + exp.amount;
      totalExpense += exp.amount;
      final d = exp.date;
      if (d != null && d.month == now.month && d.year == now.year) monthExpense += exp.amount;
    }

    final visible = _filter == 'All'
        ? state.expenses
        : state.expenses.where((e) => e.category == _filter).toList();
    final topCategory = catSums.entries.isEmpty
        ? null
        : catSums.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title removed: the shared page header names this page.
                      const Spacer(),
                      InkWell(
                        onTap: () => _showAddExpenseDialog(context, ref),
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIconsBold.plus, color: Colors.white, size: 13),
                              SizedBox(width: 5),
                              Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Hero spend card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(PhosphorIconsRegular.wallet, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'TOTAL SPEND',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFC7D2FE), letterSpacing: 1.1),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${state.expenses.length} ${state.expenses.length == 1 ? 'entry' : 'entries'}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '₹${totalExpense.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _heroStat('This month', '₹${monthExpense.toStringAsFixed(0)}'),
                          const SizedBox(width: 10),
                          _heroStat('Top category', topCategory == null ? '-' : topCategory.key),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Category Breakdown',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _expenseCategories.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _categoryRow(_expenseCategories[i], catSums[_expenseCategories[i]] ?? 0, totalExpense),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', state.expenses.length),
                      for (final cat in _expenseCategories) ...[
                        const SizedBox(width: 8),
                        _filterChip(cat, state.expenses.where((e) => e.category == cat).length),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${visible.length} shown',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(PhosphorIconsRegular.receipt, size: 34, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 10),
                        Text(
                          _filter == 'All' ? 'No expenses logged yet.' : 'Nothing logged under $_filter.',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Use Add Expense to record salon spending.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (int i = 0; i < visible.length; i++) ...[
                          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          _expenseRow(visible[i]),
                        ],
                      ],
                    ),
                  ),
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFFC7D2FE))),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
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
          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(9)),
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
                      cat,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    '₹${sum.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
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
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _expenseRow(Expense exp) {
    final style = _styleFor(exp.category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(11)),
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
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${exp.category} - ${exp.date != null ? _formatDateTime(exp.date) : '-'}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-₹${exp.amount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.accentRed),
          ),
        ],
      ),
    );
  }
}
