import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/app_page_switcher.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/app_dialog.dart';
import '../../auth/auth_provider.dart';

String _initials(String name) => name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join();

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatShortDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatMonthDay(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// --- CUSTOMERS TAB ---

class OwnerCustomersTab extends StatefulWidget {
  final ValueChanged<Customer>? onStartBill;
  final VoidCallback? onOpenNotifications;

  const OwnerCustomersTab({
    super.key,
    this.onStartBill,
    this.onOpenNotifications,
  });

  @override
  State<OwnerCustomersTab> createState() => _OwnerCustomersTabState();
}

class _OwnerCustomersTabState extends State<OwnerCustomersTab> {
  final _searchController = TextEditingController();
  Customer? _selectedCustomer;
  String _activeFilter = 'All'; // 'All', 'VIP', 'Recent'
  List<Bill>? _customerBills;
  bool _loadingBills = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer(WidgetRef ref, Customer cust) async {
    setState(() {
      _selectedCustomer = cust;
      _customerBills = null;
      _loadingBills = true;
    });
    try {
      final bills = await ref.read(appDataProvider.notifier).loadBillsForCustomer(cust.id);
      if (mounted && _selectedCustomer?.id == cust.id) {
        setState(() {
          _customerBills = bills;
          _loadingBills = false;
        });
      }
    } catch (_) {
      if (mounted && _selectedCustomer?.id == cust.id) {
        setState(() {
          _customerBills = [];
          _loadingBills = false;
        });
      }
    }
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref, List<Branch> branches) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    bool isVip = false;
    String? branchId = branches.isNotEmpty ? branches.first.id : null;
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.userPlus,
          title: 'Add New Customer',
          subtitle: 'Save their details to start tracking visits.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: appDialogFieldDecoration(label: 'Full Name *', icon: PhosphorIconsRegular.user),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: appDialogFieldDecoration(label: 'Phone Number *', icon: PhosphorIconsRegular.phone),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: appDialogFieldDecoration(label: 'Email Address', icon: PhosphorIconsRegular.envelopeSimple),
              ),
              const SizedBox(height: 12),
              if (branches.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: branchId,
                  decoration: appDialogFieldDecoration(label: 'Branch', icon: PhosphorIconsRegular.storefront),
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: Colors.white,
                  elevation: 3,
                  items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                  onChanged: (val) => setDialogState(() => branchId = val),
                ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('VIP Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  value: isVip,
                  onChanged: (val) => setDialogState(() => isVip = val),
                ),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Add Customer',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty || branchId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, phone, and branch are required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addCustomer(
                      name: name,
                      phone: phone,
                      email: emailController.text.trim(),
                      isVip: isVip,
                      branchId: branchId!,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Customer "$name" added successfully!'), backgroundColor: AppTheme.accentGreen),
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

  void _showCustomerOptions(BuildContext context, WidgetRef ref, Customer cust) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(_initials(cust.name), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cust.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          Text(cust.phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.receipt, color: Color(0xFF4F46E5)),
                  title: const Text('Start New Bill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onStartBill?.call(cust);
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.phone, color: Color(0xFF0D9488)),
                  title: const Text('Call Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ${cust.name} (${cust.phone})...'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.chatCircle, color: Color(0xFFD97706)),
                  title: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening messaging for ${cust.name}...'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.clockCounterClockwise, color: Color(0xFF4F46E5)),
                  title: const Text('View All Visits', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAllBillsDialog(context, cust, _customerBills ?? []);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllBillsDialog(BuildContext context, Customer cust, List<Bill> bills) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${cust.name} — Visit History', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                            Text('${bills.length} total visits', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(PhosphorIconsBold.x), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: bills.isEmpty
                        ? const Center(child: Text('No visits recorded yet.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: bills.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, idx) {
                              final bill = bills[idx];
                              final itemNames = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Service').where((s) => s.isNotEmpty).join(' + ');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(PhosphorIconsBold.receipt, color: Color(0xFF4F46E5), size: 18),
                                ),
                                title: Text('#${bill.invoiceNumber} • ${_formatShortDate(bill.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                subtitle: Text(itemNames.isNotEmpty ? itemNames : 'Standard Visit', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: Text('₹${bill.finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
    final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Cuts Salon';
    final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING').length;

    final query = _searchController.text.toLowerCase().trim();
    final filteredCustomers = state.customers.where((cust) {
      final matchesSearch = query.isEmpty ||
          cust.name.toLowerCase().contains(query) ||
          cust.phone.contains(query) ||
          (cust.email?.toLowerCase().contains(query) ?? false);

      if (!matchesSearch) return false;
      if (_activeFilter == 'VIP') return cust.isVip;
      if (_activeFilter == 'Recent') return cust.visitCount > 0;
      return true;
    }).toList();

    // Auto-select first customer if none selected yet
    if (_selectedCustomer == null && filteredCustomers.isNotEmpty) {
      final firstCust = filteredCustomers.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCustomer == null) {
          _selectCustomer(ref, firstCust);
        }
      });
    }

    final vipCount = state.customers.where((c) => c.isVip).length;
    final allCount = state.customers.length;

    final activeCustomer = _selectedCustomer ?? (filteredCustomers.isNotEmpty ? filteredCustomers.first : null);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            // Bottom padding ensures list is not cut off by floating bottom navbar
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Salon Header
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            PhosphorIconsBold.storefront,
                            color: Color(0xFF4F46E5),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          salonName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        // Notification bell
                        IconButton(
                          icon: Badge(
                            isLabelVisible: pendingDiscountCount > 0,
                            label: Text('$pendingDiscountCount'),
                            backgroundColor: const Color(0xFFF04438),
                            child: const Icon(
                              PhosphorIconsRegular.bell,
                              color: Color(0xFF334155),
                              size: 22,
                            ),
                          ),
                          onPressed: () {
                            if (widget.onOpenNotifications != null) {
                              widget.onOpenNotifications!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No new notifications'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Customers Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customers',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$allCount total',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddCustomerDialog(context, ref, state.branches),
                        icon: const Icon(PhosphorIconsBold.plus, size: 14, color: Colors.white),
                        label: const Text(
                          'Add Customer',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search customers by name or phone...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: Color(0xFF94A3B8), size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Filter Chips Row
                Row(
                  children: [
                    _buildFilterChip(
                      label: 'All ($allCount)',
                      isSelected: _activeFilter == 'All',
                      onTap: () => setState(() => _activeFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: '★ VIP Only ($vipCount)',
                      isSelected: _activeFilter == 'VIP',
                      onTap: () => setState(() => _activeFilter = 'VIP'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Recent',
                      icon: PhosphorIconsRegular.clock,
                      isSelected: _activeFilter == 'Recent',
                      onTap: () => setState(() => _activeFilter = 'Recent'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Selected Customer Hero Profile Card
                if (activeCustomer != null)
                  _buildCustomerHeroCard(context, ref, activeCustomer, state)
                else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No customer selected or found.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // 6. Customer Directory Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Customer Directory',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Sorted by Activity',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 7. Customer Directory List
                if (filteredCustomers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No customers match your search.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...filteredCustomers.map((cust) {
                    final isSel = activeCustomer?.id == cust.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _selectCustomer(ref, cust),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                              width: isSel ? 1.6 : 1,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSel ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF),
                                child: Text(
                                  _initials(cust.name),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: isSel ? Colors.white : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cust.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (cust.isVip) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '★ VIP Gold',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${cust.phone} • ${cust.visitCount} visits',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                PhosphorIconsBold.caretRight,
                                size: 14,
                                color: Color(0xFFCBD5E1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerHeroCard(BuildContext context, WidgetRef ref, Customer cust, AppData state) {
    final bills = _customerBills;

    // Calculate dynamic stats
    double totalSpent = cust.totalSpent;
    if (totalSpent <= 0 && bills != null && bills.isNotEmpty) {
      totalSpent = bills.fold<double>(0.0, (acc, b) => acc + b.finalAmount);
    }

    int visits = cust.visitCount;
    if (visits <= 0 && bills != null) {
      visits = bills.length;
    }

    String lastVisit = '-';
    if (cust.lastVisitAt != null) {
      lastVisit = _formatMonthDay(cust.lastVisitAt);
    } else if (bills != null && bills.isNotEmpty && bills.first.createdAt != null) {
      lastVisit = _formatMonthDay(bills.first.createdAt);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, VIP, Options
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEEF2FF),
                child: Text(
                  _initials(cust.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            cust.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cust.isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '★ VIP',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cust.phone,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsBold.dotsThree, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => _showCustomerOptions(context, ref, cust),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Action Buttons: Call, Message, New Bill
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dialing ${cust.name} (${cust.phone})...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(PhosphorIconsRegular.phone, size: 14, color: Color(0xFF334155)),
                  label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening messaging for ${cust.name}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(PhosphorIconsRegular.chatCircle, size: 14, color: Color(0xFF334155)),
                  label: const Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onStartBill?.call(cust),
                  icon: const Icon(PhosphorIconsBold.receipt, size: 14, color: Colors.white),
                  label: const Text('New Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: 3 Stat KPI Boxes: Total Spent, Visits, Last Visit
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.wallet,
                  iconBg: const Color(0xFFEEF2FF),
                  iconColor: const Color(0xFF4F46E5),
                  label: 'Total Spent',
                  value: '₹${totalSpent.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.calendarBlank,
                  iconBg: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                  label: 'Visits',
                  value: '$visits',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: PhosphorIconsFill.clock,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  label: 'Last Visit',
                  value: lastVisit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 4: Visit History Subsection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Visit History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: () => _showAllBillsDialog(context, cust, bills ?? []),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visit History Items
          if (_loadingBills)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                ),
              ),
            )
          else if (bills == null || bills.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Center(
                child: Text(
                  'No previous visits recorded yet.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ...bills.take(3).map((bill) {
              final itemSummary = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Service').where((s) => s.isNotEmpty).join(' + ');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7.0),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        PhosphorIconsBold.receipt,
                        color: Color(0xFF4F46E5),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${bill.invoiceNumber} • ${_formatShortDate(bill.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            itemSummary.isNotEmpty ? itemSummary : 'Haircut & Styling',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${bill.finalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- EMPLOYEES TAB ---

class OwnerEmployeesTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerEmployeesTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerEmployeesTab> createState() => _OwnerEmployeesTabState();
}

class _OwnerEmployeesTabState extends State<OwnerEmployeesTab> {
  EmployeeProfile? _selectedEmployee;
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _todayStatus(AppData state, String employeeId) {
    final today = DateTime.now();
    final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
    return match.isEmpty ? 'Absent' : match.first.status;
  }

  void _showAddEmployeeDialog(BuildContext context, WidgetRef ref, List<Branch> branches) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController(text: 'Hair Stylist');
    final salaryController = TextEditingController(text: '25000');
    final serviceCommController = TextEditingController(text: '15');
    final productCommController = TextEditingController(text: '5');
    bool obscurePassword = true;
    bool submitting = false;
    String? branchId = branches.isNotEmpty ? branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.userPlus,
          title: 'Create Employee Account',
          subtitle: 'They can log in immediately with these credentials.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Full Name *', hint: 'e.g. Jamie Davis', icon: PhosphorIconsRegular.user)),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: appDialogFieldDecoration(label: 'Login Email *', hint: 'e.g. jamie@salon.com', icon: PhosphorIconsRegular.envelopeSimple)),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: appDialogFieldDecoration(label: 'Login Password *', hint: 'min 8 characters', icon: PhosphorIconsRegular.lockKey).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 20),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: appDialogFieldDecoration(label: 'Phone Number *', hint: '+91 98765 43210', icon: PhosphorIconsRegular.phone)),
              const SizedBox(height: 12),
              TextField(controller: roleController, decoration: appDialogFieldDecoration(label: 'Stylist Role', hint: 'Senior Stylist / Colorist', icon: PhosphorIconsRegular.scissors)),
              const SizedBox(height: 12),
              if (branches.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: appDialogFieldDecoration(label: 'Branch', icon: PhosphorIconsRegular.storefront),
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: Colors.white,
                    elevation: 3,
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) => setDialogState(() => branchId = val),
                  ),
                ),
              TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Base Retainer (Rs.)', icon: PhosphorIconsRegular.wallet)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: serviceCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Service Comm. (%)', icon: PhosphorIconsRegular.percent))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: productCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Product Comm. (%)', icon: PhosphorIconsRegular.percent))),
                ],
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Create Account',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text;
              if (name.isEmpty || email.isEmpty || phone.isEmpty || branchId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, email, phone, and branch are required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              if (password.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 8 characters.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              final salary = double.tryParse(salaryController.text) ?? 25000;
              final serviceComm = double.tryParse(serviceCommController.text) ?? 15;
              final productComm = double.tryParse(productCommController.text) ?? 5;

              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addEmployee(
                      name: name,
                      phone: phone,
                      roleTitle: roleController.text.trim(),
                      baseSalary: salary,
                      serviceCommissionPct: serviceComm,
                      productCommissionPct: productComm,
                      email: email,
                      password: password,
                      branchId: branchId!,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Account created for $name. They can log in with the password you just set.'), backgroundColor: AppTheme.accentGreen),
                  );
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

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    // Firebase's client SDK can't set another user's password directly (no
    // Admin SDK, no server) - the owner can only trigger Firebase's own
    // reset-link email. See salon_auth.dart's sendPasswordResetEmail and
    // app_data_provider.dart's resetEmployeePassword.
    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.lockKey,
          title: 'Reset Password',
          child: Text(
            "This sends a password reset link to ${emp.email}. ${emp.name} will follow it to choose a new password themselves.",
            style: const TextStyle(fontSize: 14, color: AppTheme.slateMedium, height: 1.4),
          ),
          actions: AppDialogActions(
            submitLabel: 'Send Reset Email',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).resetEmployeePassword(emp.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset email sent to ${emp.email}.'), backgroundColor: AppTheme.accentGreen),
                  );
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

  void _showEditEmployeeDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp, List<Branch> branches) {
    final nameController = TextEditingController(text: emp.name);
    final phoneController = TextEditingController(text: emp.phone);
    final roleController = TextEditingController(text: emp.roleTitle);
    final salaryController = TextEditingController(text: emp.baseSalary.toStringAsFixed(0));
    final serviceCommController = TextEditingController(text: emp.serviceCommissionPct.toStringAsFixed(0));
    final productCommController = TextEditingController(text: emp.productCommissionPct.toStringAsFixed(0));
    // Email isn't editable here - it's also the Firebase Auth login
    // identity, and there's no Admin SDK to rename that account to match
    // (same no-server constraint as resetEmployeePassword above).
    String? branchId = emp.branchId;
    bool active = emp.active;
    // Firestore rules gate almost every write/read on isActiveEmployee()
    // (via myProfile().active) - if the owner flipped this off on their own
    // record, isOwner() would also go false on their next request, and only
    // an owner can flip it back. There's no server to catch that mistake
    // for them, so the toggle is disabled entirely on your own profile.
    final isSelf = ref.read(authControllerProvider).userId == emp.id;

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Edit ${emp.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: appDialogFieldDecoration(label: 'Full Name *', icon: PhosphorIconsRegular.user)),
              const SizedBox(height: 12),
              TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: appDialogFieldDecoration(label: 'Phone Number *', icon: PhosphorIconsRegular.phone)),
              const SizedBox(height: 12),
              TextField(controller: roleController, decoration: appDialogFieldDecoration(label: 'Stylist Role', icon: PhosphorIconsRegular.scissors)),
              const SizedBox(height: 12),
              if (branches.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: appDialogFieldDecoration(label: 'Branch', icon: PhosphorIconsRegular.storefront),
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: Colors.white,
                    elevation: 3,
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) => setDialogState(() => branchId = val),
                  ),
                ),
              TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Base Retainer (Rs.)', icon: PhosphorIconsRegular.wallet)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: serviceCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Service Comm. (%)', icon: PhosphorIconsRegular.percent))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: productCommController, keyboardType: TextInputType.number, decoration: appDialogFieldDecoration(label: 'Product Comm. (%)', icon: PhosphorIconsRegular.percent))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isSelf ? "You can't deactivate your own account here - ask another owner, or use the Firebase Console." : 'Deactivated staff can no longer sign in or be billed against.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: active,
                  onChanged: isSelf ? null : (val) => setDialogState(() => active = val),
                ),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Save Changes',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty || branchId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, phone, and branch are required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              final salary = double.tryParse(salaryController.text) ?? emp.baseSalary;
              final serviceComm = double.tryParse(serviceCommController.text) ?? emp.serviceCommissionPct;
              final productComm = double.tryParse(productCommController.text) ?? emp.productCommissionPct;

              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).updateEmployee(emp.id, {
                  'name': name,
                  'phone': phone,
                  'roleTitle': roleController.text.trim(),
                  'baseSalary': salary,
                  'serviceCommissionPct': serviceComm,
                  'productCommissionPct': productComm,
                  'branchId': branchId,
                  'active': active,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name updated.'), backgroundColor: AppTheme.accentGreen),
                  );
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

  void _showSetSalesTargetDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    String type = 'SERVICE_VOLUME';
    final targetValueController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.target,
          title: 'Set Sales Target',
          subtitle: 'For ${emp.name}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: appDialogFieldDecoration(label: 'Target Type', icon: PhosphorIconsRegular.flag),
                items: const [
                  DropdownMenuItem(value: 'SERVICE_VOLUME', child: Text('Service Revenue (Rs.)')),
                  DropdownMenuItem(value: 'PRODUCT_SALES_COUNT', child: Text('Product Units Sold')),
                ],
                onChanged: (val) => setDialogState(() => type = val ?? type),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetValueController,
                keyboardType: TextInputType.number,
                decoration: appDialogFieldDecoration(label: type == 'SERVICE_VOLUME' ? 'Target Revenue (Rs.) *' : 'Target Units *', icon: PhosphorIconsRegular.trendUp),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (picked != null) setDialogState(() => startDate = picked);
                      },
                      child: Text('Start: ${_formatDate(startDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: endDate, firstDate: startDate, lastDate: DateTime(2100));
                        if (picked != null) setDialogState(() => endDate = picked);
                      },
                      child: Text('End: ${_formatDate(endDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Set Target',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final targetValue = double.tryParse(targetValueController.text);
              if (targetValue == null || targetValue <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid target value.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).addSalesTarget(
                      employeeId: emp.id,
                      type: type,
                      targetValue: targetValue,
                      startDate: startDate.toIso8601String(),
                      endDate: endDate.toIso8601String(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Target set for ${emp.name}.'), backgroundColor: AppTheme.accentGreen),
                  );
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

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // forEmployee == null runs payroll for every active employee at once
  // (AppDataNotifier.generateSalary / SalonFirestore.generateSalary already
  // skip anyone already PAID for the chosen month, so rerunning this is
  // always safe).
  void _showGenerateSalaryDialog(BuildContext context, WidgetRef ref, {EmployeeProfile? forEmployee}) {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;

    bool submitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.moneyWavy,
          title: forEmployee == null ? 'Run Payroll for All Staff' : 'Generate Salary',
          subtitle: forEmployee == null ? null : forEmployee.name,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sums pending commissions and late-attendance deductions for the chosen month into a draft salary record${forEmployee == null ? ' for every active employee' : ''}.',
                style: const TextStyle(color: AppTheme.slateLight, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
                      decoration: appDialogFieldDecoration(label: 'Month', icon: PhosphorIconsRegular.calendarBlank),
                      items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthNames[m - 1]))],
                      onChanged: (val) => setDialogState(() => month = val ?? month),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: year,
                      decoration: appDialogFieldDecoration(label: 'Year'),
                      items: [for (var y = now.year - 1; y <= now.year; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (val) => setDialogState(() => year = val ?? year),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Generate',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              setDialogState(() => submitting = true);
              try {
                await ref.read(appDataProvider.notifier).generateSalary(month: month, year: year, employeeId: forEmployee?.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Salary generated for ${_monthNames[month - 1]} $year.'), backgroundColor: AppTheme.accentGreen),
                  );
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

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder, not MediaQuery - see the comment in OwnerCustomersTab's
    // build() for why (the sidebar means MediaQuery's width overstates the
    // space this tab actually has).
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Consumer(
          builder: (context, ref, child) {
            final asyncData = ref.watch(appDataProvider);
            return asyncData.when(
              loading: () => const AppLoadingView(),
              error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
              data: (state) => _buildBody(context, ref, state, isMobile),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppData state, bool isMobile) {
    if (isMobile) {
      return _buildMobileStaffView(context, ref, state);
    }
    return _buildDesktopStaffView(context, ref, state);
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          ),
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

  Widget _buildMobileSalonHeader(BuildContext context, String salonName, String? ownerName, int unreadCount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(
            PhosphorIconsRegular.storefront,
            size: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            salonName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {
            if (widget.onOpenNotifications != null) {
              widget.onOpenNotifications!();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No new notifications'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(PhosphorIconsRegular.bell, size: 18, color: Color(0xFF475467)),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE9FE),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(ownerName ?? '').isEmpty ? 'OW' : _initials(ownerName ?? ''),
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileStaffView(BuildContext context, WidgetRef ref, AppData state) {
    final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Cuts Salon';
    final ownerName = ref.watch(authControllerProvider).name;
    final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING').length;
    final presentCount = state.employees.where((e) => _todayStatus(state, e.id) == 'PRESENT').length;

    final q = _searchController.text.toLowerCase().trim();
    final filteredEmployees = state.employees.where((emp) {
      if (q.isNotEmpty && !emp.name.toLowerCase().contains(q) && !emp.roleTitle.toLowerCase().contains(q)) {
        return false;
      }
      if (_activeFilter == 'Present') {
        return _todayStatus(state, emp.id) == 'PRESENT';
      }
      if (_activeFilter != 'All' && !emp.roleTitle.toLowerCase().contains(_activeFilter.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    EmployeeProfile? selectedEmp;
    if (_selectedEmployee != null && state.employees.any((e) => e.id == _selectedEmployee!.id)) {
      selectedEmp = state.employees.firstWhere((e) => e.id == _selectedEmployee!.id);
    } else if (filteredEmployees.isNotEmpty) {
      selectedEmp = filteredEmployees.first;
    } else if (state.employees.isNotEmpty) {
      selectedEmp = state.employees.first;
    }

    final now = DateTime.now();
    final monthName = _monthNames[now.month - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pinned Salon Header
          _buildMobileSalonHeader(context, salonName, ownerName, pendingDiscountCount),
          const SizedBox(height: 16),

          // 2. Title & + Add Staff
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff & Stylists',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.employees.length} Active Team Members',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showAddEmployeeDialog(context, ref, state.branches),
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
                      Text(
                        'Add Staff',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Search Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search staff or role...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(PhosphorIconsRegular.xCircle, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 4. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All (${state.employees.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Present ($presentCount)', 'Present'),
                const SizedBox(width: 8),
                _buildFilterChip('Stylists', 'Stylist'),
                const SizedBox(width: 8),
                _buildFilterChip('Reception', 'Reception'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 5. Team Roster Header & Carousel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Roster',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _showAllStaffSheet(context, ref, state),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredEmployees.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text('No staff members found matching filter.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            )
          else
            SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filteredEmployees.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final emp = filteredEmployees[idx];
                  final isSelected = selectedEmp?.id == emp.id;
                  final status = _todayStatus(state, emp.id);
                  final isPresent = status == 'PRESENT';
                  final isLate = status == 'LATE';

                  final bg = _kRosterAvatarBgs[idx % _kRosterAvatarBgs.length];
                  final fg = _kRosterAvatarFgs[idx % _kRosterAvatarFgs.length];

                  return InkWell(
                    onTap: () => setState(() => _selectedEmployee = emp),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 112,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.6 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          if (isPresent)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: bg,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _initials(emp.name),
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  emp.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  emp.roleTitle,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPresent
                                        ? const Color(0xFFECFDF5)
                                        : isLate
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? const Color(0xFF10B981)
                                              : isLate
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF94A3B8),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isPresent ? 'Present' : isLate ? 'Late' : 'Absent',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isPresent
                                              ? const Color(0xFF059669)
                                              : isLate
                                                  ? const Color(0xFFD97706)
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // 6. Selected Staff Profile Details Card
          if (selectedEmp != null) ...[
            _buildSelectedStaffCard(context, ref, state, selectedEmp),
            const SizedBox(height: 14),

            // 7. Monthly Sales Target Card
            _buildSalesTargetCard(context, ref, state, selectedEmp, monthName),
            const SizedBox(height: 14),

            // 8. 2x2 Metrics Grid
            _buildMetricsGrid(context, ref, state, selectedEmp),
            const SizedBox(height: 14),

            // 9. Payroll Estimate Card
            _buildPayrollEstimateCard(context, ref, state, selectedEmp, monthName),
          ],

          const SizedBox(height: 110), // clearance for floating navbar
        ],
      ),
    );
  }

  Widget _buildSelectedStaffCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(emp.name),
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            emp.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          PhosphorIconsFill.checkCircle,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emp.roleTitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      emp.branchName != null ? 'Branch: ${emp.branchName}' : 'Chair #01 • Tier 1 Master',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3 Action Buttons: Call, Schedule, Edit
          Row(
            children: [
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.phone,
                  label: 'Call',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling ${emp.name} (${emp.phone})...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.calendarBlank,
                  label: 'Schedule',
                  onTap: () => _showScheduleSheet(context, emp, state),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStaffActionButton(
                  icon: PhosphorIconsRegular.pencilSimple,
                  label: 'Edit',
                  onTap: () => _showEditEmployeeDialog(context, ref, emp, state.branches),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // Contact Info Rows
          _buildStaffInfoRow(PhosphorIconsRegular.phone, 'Phone', emp.phone),
          const SizedBox(height: 8),
          _buildStaffInfoRow(PhosphorIconsRegular.envelopeSimple, 'Email', emp.email),
          const SizedBox(height: 8),
          _buildStaffInfoRow(PhosphorIconsRegular.calendarCheck, 'Tenure', 'Active Staff Member'),
        ],
      ),
    );
  }

  Widget _buildStaffActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF475467)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTargetCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp, String monthName) {
    final activeTargets = state.salesTargets.where((t) => t.employeeId == emp.id && t.status == 'ACTIVE').toList();
    final target = activeTargets.isNotEmpty ? activeTargets.first : null;

    // No fabricated numbers when there's no real target - this used to
    // invent a fake "achieved" figure from the employee's salary and a fake
    // ₹1,80,000 goal, which showed the owner a made-up performance number
    // with nothing behind it. Show an honest empty state instead.
    if (target == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                PhosphorIconsRegular.trendUp,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No active sales target set',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$monthName progress will show here once one is set.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showSetSalesTargetDialog(context, ref, emp),
              child: const Text('Set Target'),
            ),
          ],
        ),
      );
    }

    final targetAchieved = target.progressValue;
    final targetGoal = target.targetValue > 0 ? target.targetValue : 1.0;
    final targetPct = target.progressFraction;
    final toTarget = (targetGoal - targetAchieved).clamp(0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.trendUp,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$monthName Sales Target',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(targetPct * 100).toInt()}% Goal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${targetAchieved.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'of ₹${targetGoal.toStringAsFixed(0)} goal',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: targetPct.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFEEF2FF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                targetPct >= 1.0 ? 'Target reached' : 'In progress',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '₹${toTarget.toStringAsFixed(0)} to target',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: [
        _buildMetricItemTile(
          icon: PhosphorIconsRegular.checkCircle,
          iconColor: const Color(0xFF10B981),
          iconBg: const Color(0xFFECFDF5),
          badgeText: 'This Month',
          badgeColor: const Color(0xFF10B981),
          badgeBg: const Color(0xFFECFDF5),
          value: '${attendancePct.toInt()}%',
          title: 'Attendance %',
          subtext: '$presentDays/${monthAttendance.length} Days Logged',
        ),
        _buildMetricItemTile(
          icon: PhosphorIconsRegular.identificationCard,
          iconColor: const Color(0xFF6366F1),
          iconBg: const Color(0xFFEDE9FE),
          badgeText: 'Fixed',
          badgeColor: const Color(0xFF6366F1),
          badgeBg: const Color(0xFFEDE9FE),
          value: '₹${emp.baseSalary.toStringAsFixed(0)}',
          title: 'Base Salary',
          subtext: 'Fixed Monthly',
        ),
        _buildMetricItemTile(
          icon: PhosphorIconsRegular.scissors,
          iconColor: const Color(0xFF8B5CF6),
          iconBg: const Color(0xFFF5F3FF),
          badgeText: '${emp.serviceCommissionPct.toInt()}% Tier',
          badgeColor: const Color(0xFF8B5CF6),
          badgeBg: const Color(0xFFF5F3FF),
          value: '${emp.serviceCommissionPct.toInt()}%',
          title: 'Service Comm.',
          subtext: 'On services',
        ),
        _buildMetricItemTile(
          icon: PhosphorIconsRegular.tote,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          badgeText: '${emp.productCommissionPct.toInt()}% Tier',
          badgeColor: const Color(0xFFD97706),
          badgeBg: const Color(0xFFFEF3C7),
          value: '${emp.productCommissionPct.toInt()}%',
          title: 'Product Comm.',
          subtext: 'On retail',
        ),
      ],
    );
  }

  Widget _buildMetricItemTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required String value,
    required String title,
    required String subtext,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollEstimateCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp, String monthName) {
    final pendingCommissions = state.commissions.where((c) => c.employeeId == emp.id && c.status == 'PENDING').toList();
    final pendingCommissionTotal = pendingCommissions.fold<double>(0, (sum, c) => sum + c.amount);

    final serviceComm = pendingCommissionTotal > 0
        ? pendingCommissionTotal * 0.85
        : (emp.baseSalary * (emp.serviceCommissionPct / 100) * 2.5);
    final productComm = pendingCommissionTotal > 0
        ? pendingCommissionTotal * 0.15
        : (emp.baseSalary * (emp.productCommissionPct / 100) * 1.2);

    final projectedPayout = emp.baseSalary + (pendingCommissionTotal > 0 ? pendingCommissionTotal : (serviceComm + productComm));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYROLL ESTIMATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6366F1),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Projected Payout (${monthName.substring(0, 3)})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsRegular.receipt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${projectedPayout.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4F46E5),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'gross earnings',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFDDD6FE)),
          const SizedBox(height: 10),
          _buildPayrollBreakdownRow('Base Pay', '₹${emp.baseSalary.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          _buildPayrollBreakdownRow(
            'Service Commission (${emp.serviceCommissionPct.toInt()}%)',
            '+ ₹${serviceComm.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _buildPayrollBreakdownRow(
            'Product Commission (${emp.productCommissionPct.toInt()}%)',
            '+ ₹${productComm.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _showDetailedSlipSheet(context, ref, state, emp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Detailed Slip',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  Icon(PhosphorIconsBold.arrowRight, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollBreakdownRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475467),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showScheduleSheet(BuildContext context, EmployeeProfile emp, AppData state) {
    final recentAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null).toList()
      ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                const SizedBox(height: 14),
                Text(
                  '${emp.name}\'s Schedule & Attendance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recent check-ins and shifts for this month',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                if (recentAttendance.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No attendance records logged yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      itemCount: recentAttendance.length > 8 ? 8 : recentAttendance.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final rec = recentAttendance[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_formatDate(rec.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text('Shift: Morning & Evening', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: rec.status == 'PRESENT'
                                  ? const Color(0xFFECFDF5)
                                  : rec.status == 'LATE'
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rec.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: rec.status == 'PRESENT'
                                    ? const Color(0xFF059669)
                                    : rec.status == 'LATE'
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailedSlipSheet(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${emp.name} • Payroll Slip',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Salary records and pending commission breakdown',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showGenerateSalaryDialog(context, ref, forEmployee: emp);
                        },
                        icon: const Icon(PhosphorIconsRegular.calendarPlus, color: Color(0xFF6366F1)),
                        tooltip: 'Generate Salary',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPendingCommissionsCard(context, ref, state, emp),
                  const SizedBox(height: 16),
                  _buildSalaryHistoryCard(context, ref, state, emp),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllStaffSheet(BuildContext context, WidgetRef ref, AppData state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Staff Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEmployeeDialog(context, ref, state.branches);
                        },
                        icon: const Icon(PhosphorIconsBold.plus, size: 14),
                        label: const Text('Add Staff', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: state.employees.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final emp = state.employees[idx];
                        final status = _todayStatus(state, emp.id);
                        final isPresent = status == 'PRESENT';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEDE9FE),
                            child: Text(
                              _initials(emp.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            emp.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            '${emp.roleTitle} • ${emp.phone}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPresent ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isPresent ? const Color(0xFF059669) : const Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          onTap: () {
                            setState(() => _selectedEmployee = emp);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopStaffView(BuildContext context, WidgetRef ref, AppData state) {
    final presentCount = state.employees.where((e) => _todayStatus(state, e.id) == 'PRESENT').length;

    final Widget listColumn = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Staff & Stylists',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark),
                ),
              ),
              IconButton(
                onPressed: () => _showGenerateSalaryDialog(context, ref),
                icon: const Icon(PhosphorIconsRegular.moneyWavy, color: AppTheme.primaryBlue),
                tooltip: 'Run Payroll for All Staff',
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEmployeeDialog(context, ref, state.branches),
                icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                label: const Text('Add Staff', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: const Size(0, 34)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Active on Shift: $presentCount / ${state.employees.length}',
            style: const TextStyle(color: AppTheme.slateLight, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.employees.isEmpty
                ? const Center(child: Text('No employees yet.', style: TextStyle(color: AppTheme.slateLight)))
                : ListView.builder(
                    itemCount: state.employees.length,
                    itemBuilder: (context, idx) {
                      final emp = state.employees[idx];
                      final isSel = _selectedEmployee?.id == emp.id;
                      final status = _todayStatus(state, emp.id);
                      Color statusColor = AppTheme.accentGreen;
                      if (status == 'LATE') statusColor = AppTheme.accentAmber;
                      if (status == 'ABSENT') statusColor = AppTheme.slateLight;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryLight : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? AppTheme.primaryBlue : AppTheme.borderSubtle, width: 1),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryLight,
                            child: Text(_initials(emp.name), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  emp.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          subtitle: Text('${emp.roleTitle} • ${emp.email}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                          onTap: () => setState(() => _selectedEmployee = emp),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    return Row(
      children: [
        Expanded(flex: 1, child: listColumn),
        Expanded(
          flex: 1,
          child: AppPageSwitcher(
            child: _selectedEmployee == null
                ? const Center(
                    key: ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.identificationBadge, size: 56, color: AppTheme.slateLight),
                        SizedBox(height: 12),
                        Text('Select an employee to view details & metrics', style: TextStyle(color: AppTheme.slateMedium)),
                      ],
                    ),
                  )
                : Container(key: ValueKey('employee-${_selectedEmployee!.id}'), child: _buildEmployeeProfile(context, ref, state)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeProfile(BuildContext context, WidgetRef ref, AppData state) {
    final emp = state.employees.firstWhere((e) => e.id == _selectedEmployee!.id, orElse: () => _selectedEmployee!);

    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.employeeId == emp.id && a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    final activeTargets = state.salesTargets.where((t) => t.employeeId == emp.id && t.status == 'ACTIVE').toList();
    final target = activeTargets.isNotEmpty ? activeTargets.first : null;

    final pendingCommission = state.commissions
        .where((c) => c.employeeId == emp.id && c.status == 'PENDING')
        .fold<double>(0, (sum, c) => sum + c.amount);
    final projectedPayout = emp.baseSalary + pendingCommission;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(_initials(emp.name), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark)),
                      Text(emp.roleTitle, style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Phone: ${emp.phone}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      Text('Email: ${emp.email}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      if (emp.branchName != null) Text('Branch: ${emp.branchName}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEditEmployeeDialog(context, ref, emp, state.branches),
                  icon: const Icon(PhosphorIconsRegular.pencilSimple, color: AppTheme.slateLight),
                  tooltip: 'Edit Employee',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sales Target', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark)),
                    TextButton.icon(
                      onPressed: () => _showSetSalesTargetDialog(context, ref, emp),
                      icon: const Icon(PhosphorIconsRegular.target, size: 15),
                      label: Text(target == null ? 'Set Target' : 'New Target', style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
                    ),
                  ],
                ),
                if (target == null)
                  const Text('No active sales target set.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                else ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${target.type == 'SERVICE_VOLUME' ? 'Service Revenue' : 'Product Units'} target', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                      Text('${(target.progressFraction * 100).toStringAsFixed(0)}% Achieved', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w800, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: target.progressFraction, backgroundColor: const Color(0xFFE2E8F0), valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue), minHeight: 7),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Achieved: ${target.progressValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                      Text('Target: ${target.targetValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Attendance (Month)', '${attendancePct.toStringAsFixed(0)}%', PhosphorIconsRegular.calendarBlank, AppTheme.accentGreen)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Base Salary', 'Rs. ${emp.baseSalary.toStringAsFixed(0)}', PhosphorIconsRegular.money, AppTheme.slateDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Service Commission', '${emp.serviceCommissionPct.toStringAsFixed(0)}%', PhosphorIconsRegular.percent, AppTheme.primaryBlue)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricCard('Product Commission', '${emp.productCommissionPct.toStringAsFixed(0)}%', PhosphorIconsRegular.percent, AppTheme.primaryBlue)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projected Payout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark)),
                    Text('Base salary + pending commission', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                  ],
                ),
                Text('Rs. ${projectedPayout.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.accentGreen)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPendingCommissionsCard(context, ref, state, emp),
          const SizedBox(height: 16),
          _buildSalaryHistoryCard(context, ref, state, emp),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showResetPasswordDialog(context, ref, emp),
              icon: const Icon(PhosphorIconsRegular.lockKey, size: 18, color: AppTheme.primaryBlue),
              label: const Text('Reset Employee Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCommissionsCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final pending = state.commissions.where((c) => c.employeeId == emp.id && c.status == 'PENDING').toList()
      ..sort((a, b) => (b.calculatedAt ?? DateTime(0)).compareTo(a.calculatedAt ?? DateTime(0)));

    Future<void> markPaid(String id) async {
      try {
        await ref.read(appDataProvider.notifier).markCommissionPaid(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pending Commissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark)),
          const SizedBox(height: 4),
          const Text('Paid off automatically the next time payroll runs for the covering month, or mark one individually below.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const Text('No pending commissions.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pending.length > 20 ? 20 : pending.length,
              itemBuilder: (context, idx) {
                final c = pending[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(c.calculatedAt), style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
                      Row(
                        children: [
                          Text('Rs. ${c.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 26,
                            child: TextButton(
                              onPressed: () => markPaid(c.id),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 26)),
                              child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryHistoryCard(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final records = state.salaryRecords.where((r) => r.employeeId == emp.id).toList()
      ..sort((a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));

    Future<void> markPaid(String id) async {
      try {
        await ref.read(appDataProvider.notifier).markSalaryPaid(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Salary History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark)),
              TextButton.icon(
                onPressed: () => _showGenerateSalaryDialog(context, ref, forEmployee: emp),
                icon: const Icon(PhosphorIconsRegular.calendarPlus, size: 15),
                label: const Text('Generate', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Text('No salary records yet - generate one for a past month above.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              itemBuilder: (context, idx) {
                final r = records[idx];
                final isPaid = r.status == 'PAID';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.borderSubtle)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_monthNames[r.month - 1]} ${r.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            Text('Base Rs. ${r.baseSalary.toStringAsFixed(0)} + Commission Rs. ${r.commissionEarned.toStringAsFixed(0)} - Deductions Rs. ${r.deductions.toStringAsFixed(0)}',
                                style: const TextStyle(color: AppTheme.slateLight, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('Rs. ${r.totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 10),
                      if (isPaid)
                        const Icon(PhosphorIconsRegular.checkCircle, color: AppTheme.accentGreen, size: 20)
                      else
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => markPaid(r.id),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 28)),
                            child: const Text('Mark Paid', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppTheme.slateLight, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }
}

// --- ATTENDANCE TAB ---

const List<Color> _kRosterAvatarBgs = [
  Color(0xFFEEF2FF),
  Color(0xFFFEF3C7),
  Color(0xFFF5F3FF),
  Color(0xFFCCFBF1),
  Color(0xFFFCE7F3),
  Color(0xFFF1F5F9),
];

const List<Color> _kRosterAvatarFgs = [
  Color(0xFF4F46E5),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFF0D9488),
  Color(0xFFDB2777),
  Color(0xFF475467),
];

String _formatRosterDate(DateTime? d) {
  if (d == null) return '-';
  final now = DateTime.now();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  final timeStr = '$hour:$minute $period In';

  if (now.year == d.year && now.month == d.month && now.day == d.day) {
    return 'Today, ${d.day} ${months[d.month - 1]} • $timeStr';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (yesterday.year == d.year && yesterday.month == d.month && yesterday.day == d.day) {
    return 'Yesterday, ${d.day} ${months[d.month - 1]} • $timeStr';
  }
  return '${d.day} ${months[d.month - 1]} ${d.year} • $timeStr';
}

class OwnerAttendanceTab extends StatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerAttendanceTab({super.key, this.onOpenNotifications});

  @override
  State<OwnerAttendanceTab> createState() => _OwnerAttendanceTabState();
}

class _OwnerAttendanceTabState extends State<OwnerAttendanceTab> {
  final Map<String, String> _localRosterStatus = {};
  bool _submittingRoster = false;

  String _statusFor(AppData state, String employeeId) {
    if (_localRosterStatus.containsKey(employeeId)) {
      return _localRosterStatus[employeeId]!;
    }
    final today = DateTime.now();
    final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
    return match.isEmpty ? 'ABSENT' : match.first.status;
  }

  void _showAllHistoryModal(BuildContext context, List<AttendanceRecord> records, AppData state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  const Text('Attendance History Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: records.isEmpty
                        ? const Center(child: Text('No attendance history recorded.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: records.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final rec = records[idx];
                              final emp = state.employeeById(rec.employeeId);
                              return _buildLogTile(rec, emp);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogTile(AttendanceRecord rec, EmployeeProfile? emp) {
    Color dotColor = const Color(0xFF10B981);
    Color badgeBg = const Color(0xFFECFDF5);
    Color badgeFg = const Color(0xFF059669);

    if (rec.status == 'LATE') {
      dotColor = const Color(0xFFF59E0B);
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFFD97706);
    } else if (rec.status == 'ABSENT') {
      dotColor = const Color(0xFFEF4444);
      badgeBg = const Color(0xFFFEF2F2);
      badgeFg = const Color(0xFFDC2626);
    } else if (rec.status == 'LEAVE') {
      dotColor = const Color(0xFFF97316);
      badgeBg = const Color(0xFFFFF7ED);
      badgeFg = const Color(0xFFEA580C);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp?.name ?? 'Staff Member',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRosterDate(rec.date),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              rec.status,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeFg, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRosterRow(EmployeeProfile emp, int index, String currentStatus) {
    final bg = _kRosterAvatarBgs[index % _kRosterAvatarBgs.length];
    final fg = _kRosterAvatarFgs[index % _kRosterAvatarFgs.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          // Initials Avatar Squircle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _initials(emp.name),
                style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  emp.roleTitle.isNotEmpty ? emp.roleTitle : 'Stylist Specialist',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 3-Way Status Toggle Capsule
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusCircle(emp.id, 'P', 'PRESENT', currentStatus == 'PRESENT', const Color(0xFF10B981)),
                const SizedBox(width: 4),
                _buildStatusCircle(emp.id, 'L', 'LATE', currentStatus == 'LATE', const Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                _buildStatusCircle(emp.id, 'A', 'ABSENT', currentStatus == 'ABSENT', const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCircle(String empId, String letter, String statusKey, bool isSelected, Color activeColor) {
    return InkWell(
      onTap: () {
        setState(() {
          _localRosterStatus[empId] = statusKey;
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
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

  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Cuts Salon';
    final ownerName = ref.watch(authControllerProvider).name;
    final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING').length;
    final isMobile = MediaQuery.of(context).size.width < 768;

    int presentCount = 0;
    for (final emp in state.employees) {
      final s = _statusFor(state, emp.id);
      if (s == 'PRESENT' || s == 'LATE') presentCount++;
    }

    final today = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final todayFormatted = 'Today, ${today.day} ${months[today.month - 1]}';

    final recentAttendance = [...state.attendance]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    return Container(
      color: const Color(0xFFF8F9FC),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Pinned Top Salon Header
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            PhosphorIconsBold.storefront,
                            color: Color(0xFF4F46E5),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            salonName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Badge(
                            isLabelVisible: pendingDiscountCount > 0,
                            label: Text('$pendingDiscountCount'),
                            backgroundColor: const Color(0xFFF04438),
                            child: const Icon(
                              PhosphorIconsRegular.bell,
                              color: Color(0xFF334155),
                              size: 22,
                            ),
                          ),
                          onPressed: () {
                            if (widget.onOpenNotifications != null) {
                              widget.onOpenNotifications!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No new notifications'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1B4B),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _initials(ownerName ?? '').isEmpty ? 'OW' : _initials(ownerName ?? ''),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Title & Calendar Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Attendance',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Daily roster & staff check-in',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Date set to $todayFormatted'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(PhosphorIconsRegular.calendarBlank, size: 20, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Date & Quick Action Status Pills Row
                Row(
                  children: [
                    // Status Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$todayFormatted  •  ',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$presentCount/${state.employees.length} Present',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Mark All Present Pill
                    InkWell(
                      onTap: () {
                        setState(() {
                          for (final emp in state.employees) {
                            _localRosterStatus[emp.id] = 'PRESENT';
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All staff marked Present for today! Tap Confirm to save.'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E7FF)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(PhosphorIconsBold.check, size: 13, color: Color(0xFF4F46E5)),
                            SizedBox(width: 5),
                            Text(
                              'Mark All Present',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 4. Card 1: Mark Roster Today
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
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Mark Roster Today',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Shift: Morning & Evening',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Live',
                              style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Staff Roster Items
                      if (state.employees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: Text('No employees found in system.', style: TextStyle(color: Color(0xFF64748B)))),
                        )
                      else
                        ...state.employees.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final emp = entry.value;
                          final status = _statusFor(state, emp.id);
                          return _buildStaffRosterRow(emp, idx, status);
                        }),

                      const SizedBox(height: 8),

                      // Confirm Daily Roster Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
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
                          child: ElevatedButton(
                            onPressed: _submittingRoster
                                ? null
                                : () async {
                                    setState(() => _submittingRoster = true);
                                    final dateStr = DateTime.now().toIso8601String().split('T').first;
                                    try {
                                      for (final emp in state.employees) {
                                        final status = _statusFor(state, emp.id);
                                        await ref.read(appDataProvider.notifier).markAttendance(
                                              employeeId: emp.id,
                                              date: dateStr,
                                              status: status,
                                            );
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Daily roster confirmed successfully!'),
                                            backgroundColor: Color(0xFF10B981),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _submittingRoster = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _submittingRoster
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(PhosphorIconsBold.checkCircle, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirm Daily Roster',
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Card 2: Recent Attendance Log
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
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  PhosphorIconsBold.clockCounterClockwise,
                                  color: Color(0xFF4F46E5),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Attendance Log',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showAllHistoryModal(context, recentAttendance, state),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                'View History',
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
                      const SizedBox(height: 14),

                      // List of Logs
                      if (recentAttendance.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text('No attendance records logged yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ),
                        )
                      else
                        ...recentAttendance.take(5).map((rec) {
                          final emp = state.employeeById(rec.employeeId);
                          return _buildLogTile(rec, emp);
                        }),
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
}

