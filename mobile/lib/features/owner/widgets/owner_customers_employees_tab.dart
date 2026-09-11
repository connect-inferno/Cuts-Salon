import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/app_page_switcher.dart';
import '../../../widgets/async_state_views.dart';
import '../../auth/auth_provider.dart';

String _initials(String name) => name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join();

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// --- CUSTOMERS TAB ---

class OwnerCustomersTab extends StatefulWidget {
  const OwnerCustomersTab({super.key});

  @override
  State<OwnerCustomersTab> createState() => _OwnerCustomersTabState();
}

class _OwnerCustomersTabState extends State<OwnerCustomersTab> {
  final _searchController = TextEditingController();
  Customer? _selectedCustomer;
  bool _vipOnly = false;
  // Null while loading; see _selectCustomer.
  List<Bill>? _customerBills;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomer(WidgetRef ref, Customer cust) async {
    setState(() {
      _selectedCustomer = cust;
      _customerBills = null;
    });
    try {
      final bills = await ref.read(appDataProvider.notifier).loadBillsForCustomer(cust.id);
      if (mounted && _selectedCustomer?.id == cust.id) setState(() => _customerBills = bills);
    } catch (_) {
      if (mounted && _selectedCustomer?.id == cust.id) setState(() => _customerBills = []);
    }
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref, List<Branch> branches) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    bool isVip = false;
    String? branchId = branches.isNotEmpty ? branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                const SizedBox(height: 12),
                if (branches.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: branchId,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: Colors.white,
                    elevation: 3,
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) => setDialogState(() => branchId = val),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('VIP Customer'),
                  value: isVip,
                  onChanged: (val) => setDialogState(() => isVip = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty || branchId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name, phone, and branch are required.'), backgroundColor: AppTheme.accentRed),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(appDataProvider.notifier).addCustomer(
                        name: name,
                        phone: phone,
                        email: emailController.text.trim(),
                        isVip: isVip,
                        branchId: branchId!,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Customer "$name" added successfully!'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder, not MediaQuery, because this tab is hosted inside the
    // owner shell's sidebar layout - MediaQuery's width is the whole
    // window, not the space actually left after the sidebar, which used to
    // make this tab pick a split-view layout it didn't have room for.
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
    final query = _searchController.text.toLowerCase().trim();
    final filteredCustomers = state.customers.where((cust) {
      final matchesSearch = query.isEmpty ||
          cust.name.toLowerCase().contains(query) ||
          cust.phone.contains(query) ||
          (cust.email?.toLowerCase().contains(query) ?? false);
      final matchesFilter = !_vipOnly || cust.isVip;
      return matchesSearch && matchesFilter;
    }).toList();

    final Widget listColumn = Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Customers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.userPlus, color: AppTheme.primaryBlue),
                  tooltip: 'Add Customer',
                  onPressed: () => _showAddCustomerDialog(context, ref, state.branches),
                ),
                Text(
                  'Total: ${state.customers.length}',
                  style: TextStyle(color: AppTheme.slateLight, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or email...',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderSubtle),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
            FilterChip(
              label: const Text('VIP Only', style: TextStyle(fontSize: 11)),
              selected: _vipOnly,
              selectedColor: AppTheme.accentGold.withValues(alpha: 0.15),
              onSelected: (val) => setState(() => _vipOnly = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredCustomers.isEmpty
                  ? const Center(child: Text('No customers found.', style: TextStyle(color: AppTheme.slateLight)))
                  : ListView.builder(
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final cust = filteredCustomers[index];
                        final isSel = _selectedCustomer?.id == cust.id;

                        return Card(
                          elevation: 0,
                          color: isSel ? AppTheme.primaryLight : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSel ? AppTheme.primaryBlue : AppTheme.borderSubtle, width: 1),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryLight,
                              child: Text(_initials(cust.name), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12)),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                ),
                                if (cust.isVip) const Icon(PhosphorIconsFill.star, color: AppTheme.accentGold, size: 14),
                              ],
                            ),
                            subtitle: Text('${cust.phone} • ${cust.visitCount} visits', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                            onTap: () => _selectCustomer(ref, cust),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    if (isMobile) {
      if (_selectedCustomer != null) {
        return AppPageSwitcher(
          key: const ValueKey('mobile-detail'),
          child: Column(
            key: ValueKey('customer-${_selectedCustomer!.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedCustomer = null),
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                  label: const Text('Back to Customers Directory'),
                ),
              ),
              Expanded(child: _buildCustomerProfile(state)),
            ],
          ),
        );
      }
      return AppPageSwitcher(key: const ValueKey('mobile-list'), child: listColumn);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: listColumn),
        Expanded(
          flex: 1,
          child: AppPageSwitcher(
            child: _selectedCustomer == null
                ? const Center(
                    key: ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIconsRegular.mapPinArea, size: 64, color: AppTheme.slateLight),
                        SizedBox(height: 12),
                        Text('Select a customer to view profile details'),
                      ],
                    ),
                  )
                : Container(key: ValueKey('customer-${_selectedCustomer!.id}'), child: _buildCustomerProfile(state)),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerProfile(AppData state) {
    final cust = state.customers.firstWhere((c) => c.id == _selectedCustomer!.id, orElse: () => _selectedCustomer!);
    // Recent visit history only (fetched on demand in _selectCustomer, capped
    // server-side) - totalSpent/visitCount/lastVisit below come from fields
    // denormalized onto the customer doc instead, so they stay correct even
    // past that cap.
    final custBills = _customerBills;
    final servicesTaken = <String>{
      for (final bill in custBills ?? const <Bill>[])
        for (final item in bill.items)
          if (item.serviceName != null) item.serviceName! else if (item.productName != null) item.productName!
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Text(_initials(cust.name), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          if (cust.isVip) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(PhosphorIconsFill.star, color: AppTheme.accentGold, size: 18)),
                        ]),
                        const SizedBox(height: 4),
                        if (cust.email != null && cust.email!.isNotEmpty)
                          Text(cust.email!, style: TextStyle(color: AppTheme.slateMedium, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(cust.phone, style: TextStyle(color: AppTheme.slateMedium, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildProfileStatCard('Total Spent', 'Rs. ${cust.totalSpent.toStringAsFixed(0)}', PhosphorIconsRegular.money, AppTheme.statViolet)),
              const SizedBox(width: 12),
              Expanded(child: _buildProfileStatCard('Visit Count', '${cust.visitCount} visits', PhosphorIconsRegular.calendarCheck, AppTheme.primaryBlue)),
              const SizedBox(width: 12),
              Expanded(child: _buildProfileStatCard('Last Visit', cust.lastVisitAt == null ? 'Never' : _formatDate(cust.lastVisitAt), PhosphorIconsRegular.clock, AppTheme.statTeal)),
            ],
          ),
          const SizedBox(height: 24),
          if (servicesTaken.isNotEmpty) ...[
            const Text('Services Availed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('From their most recent visits.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: servicesTaken.map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFF9FAFB),
                    side: BorderSide(color: AppTheme.borderSubtle),
                  )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Visit History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Most recent visits.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
          const SizedBox(height: 12),
          if (custBills == null)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
          else if (custBills.isEmpty)
            const Text('No bills yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: custBills.length,
              itemBuilder: (context, idx) {
                final bill = custBills[idx];
                final itemNames = bill.items.map((i) => i.serviceName ?? i.productName ?? 'Item').join(', ');
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.borderSubtle)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryLight,
                      child: const Icon(PhosphorIconsRegular.receipt, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: Text(itemNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                    subtitle: Text('${bill.invoiceNumber} • ${_formatDate(bill.createdAt)}', style: TextStyle(color: AppTheme.slateLight, fontSize: 10)),
                    trailing: Text('Rs. ${bill.finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProfileStatCard(String label, String val, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(color: AppTheme.slateLight, fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

// --- EMPLOYEES TAB ---

class OwnerEmployeesTab extends StatefulWidget {
  const OwnerEmployeesTab({super.key});

  @override
  State<OwnerEmployeesTab> createState() => _OwnerEmployeesTabState();
}

class _OwnerEmployeesTabState extends State<OwnerEmployeesTab> {
  EmployeeProfile? _selectedEmployee;

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
    String? branchId = branches.isNotEmpty ? branches.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(PhosphorIconsRegular.userPlus, color: AppTheme.primaryBlue),
              SizedBox(width: 10),
              Text('Create Employee Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Jamie Davis')),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Login Email *', hintText: 'e.g. jamie@salon.com')),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Login Password *',
                    hintText: 'min 8 characters',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? PhosphorIconsRegular.eyeSlash : PhosphorIconsRegular.eye, size: 20),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number *', hintText: '+91 98765 43210')),
                const SizedBox(height: 12),
                TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Stylist Role', hintText: 'Senior Stylist / Colorist')),
                const SizedBox(height: 12),
                if (branches.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                      elevation: 3,
                      items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setDialogState(() => branchId = val),
                    ),
                  ),
                TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Retainer (Rs.)')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: serviceCommController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Service Commission (%)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: productCommController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Product Commission (%)'))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
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

                Navigator.pop(ctx);
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Account created for $name. They can log in with the password you just set.'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                  }
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    // Firebase's client SDK can't set another user's password directly (no
    // Admin SDK, no server) - the owner can only trigger Firebase's own
    // reset-link email. See salon_auth.dart's sendPasswordResetEmail and
    // app_data_provider.dart's resetEmployeePassword.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password for ${emp.name}'),
        content: Text("This sends a password reset link to ${emp.email}. They'll follow it to choose a new password themselves."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(appDataProvider.notifier).resetEmployeePassword(emp.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset email sent to ${emp.email}.'), backgroundColor: AppTheme.accentGreen),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                }
              }
            },
            child: const Text('Send Reset Email'),
          ),
        ],
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(PhosphorIconsRegular.pencilSimple, color: AppTheme.primaryBlue),
              const SizedBox(width: 10),
              Expanded(child: Text('Edit ${emp.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number *')),
                const SizedBox(height: 12),
                TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Stylist Role')),
                const SizedBox(height: 12),
                if (branches.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: branchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                      elevation: 3,
                      items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setDialogState(() => branchId = val),
                    ),
                  ),
                TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Retainer (Rs.)')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: serviceCommController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Service Commission (%)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: productCommController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Product Commission (%)'))),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    isSelf ? "You can't deactivate your own account here - ask another owner, or use the Firebase Console." : 'Deactivated staff can no longer sign in or be billed against.',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: active,
                  onChanged: isSelf ? null : (val) => setDialogState(() => active = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
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

                Navigator.pop(ctx);
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name updated.'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetSalesTargetDialog(BuildContext context, WidgetRef ref, EmployeeProfile emp) {
    String type = 'SERVICE_VOLUME';
    final targetValueController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Set Sales Target for ${emp.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Target Type'),
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
                  decoration: InputDecoration(labelText: type == 'SERVICE_VOLUME' ? 'Target Revenue (Rs.) *' : 'Target Units *'),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final targetValue = double.tryParse(targetValueController.text);
                if (targetValue == null || targetValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid target value.'), backgroundColor: AppTheme.accentRed),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await ref.read(appDataProvider.notifier).addSalesTarget(
                        employeeId: emp.id,
                        type: type,
                        targetValue: targetValue,
                        startDate: startDate.toIso8601String(),
                        endDate: endDate.toIso8601String(),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Target set for ${emp.name}.'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                  }
                }
              },
              child: const Text('Set Target'),
            ),
          ],
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            forEmployee == null ? 'Run Payroll for All Staff' : 'Generate Salary for ${forEmployee.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
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
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthNames[m - 1]))],
                      onChanged: (val) => setDialogState(() => month = val ?? month),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: [for (var y = now.year - 1; y <= now.year; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (val) => setDialogState(() => year = val ?? year),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(appDataProvider.notifier).generateSalary(month: month, year: year, employeeId: forEmployee?.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Salary generated for ${_monthNames[month - 1]} $year.'), backgroundColor: AppTheme.accentGreen),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                  }
                }
              },
              child: const Text('Generate'),
            ),
          ],
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
    final presentCount = state.employees.where((e) => _todayStatus(state, e.id) == 'PRESENT').length;

    final Widget listColumn = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile ? BorderRadius.circular(16) : const BorderRadius.horizontal(left: Radius.circular(16)),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: Text('Staff & Stylists', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark))),
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
          Text('Active on Shift: $presentCount / ${state.employees.length}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 12, fontWeight: FontWeight.w600)),
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
                              Expanded(child: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.slateDark), overflow: TextOverflow.ellipsis)),
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

    if (isMobile) {
      if (_selectedEmployee != null) {
        return AppPageSwitcher(
          key: const ValueKey('mobile-detail'),
          child: Column(
            key: ValueKey('employee-${_selectedEmployee!.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                child: TextButton.icon(
                  onPressed: () => setState(() => _selectedEmployee = null),
                  icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 18),
                  label: const Text('Back to Staff List'),
                ),
              ),
              Expanded(child: _buildEmployeeProfile(context, ref, state)),
            ],
          ),
        );
      }
      return AppPageSwitcher(key: const ValueKey('mobile-list'), child: listColumn);
    }

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
          Text('Paid off automatically the next time payroll runs for the covering month, or mark one individually below.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
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

class OwnerAttendanceTab extends StatefulWidget {
  const OwnerAttendanceTab({super.key});

  @override
  State<OwnerAttendanceTab> createState() => _OwnerAttendanceTabState();
}

class _OwnerAttendanceTabState extends State<OwnerAttendanceTab> {
  String _statusFor(AppData state, String employeeId) {
    final today = DateTime.now();
    final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
    return match.isEmpty ? 'ABSENT' : match.first.status;
  }

  Widget _buildRosterItem(BuildContext context, WidgetRef ref, AppData state, EmployeeProfile emp) {
    final status = _statusFor(state, emp.id);
    final segment = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'PRESENT', label: Text('P', style: TextStyle(fontSize: 10))),
        ButtonSegment(value: 'LATE', label: Text('L', style: TextStyle(fontSize: 10))),
        ButtonSegment(value: 'ABSENT', label: Text('A', style: TextStyle(fontSize: 10))),
      ],
      selected: {status},
      onSelectionChanged: (Set<String> newSelection) async {
        final dateStr = DateTime.now().toIso8601String().split('T').first;
        try {
          await ref.read(appDataProvider.notifier).markAttendance(employeeId: emp.id, date: dateStr, status: newSelection.first);
          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Attendance updated for ${emp.name}'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
          }
        }
      },
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
    );

    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.borderSubtle)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(builder: (context, cons) {
          final isTight = cons.maxWidth < 480;
          final Widget avatarAndInfo = Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Text(_initials(emp.name), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 11)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                    Text(emp.roleTitle, style: TextStyle(color: AppTheme.slateLight, fontSize: 10), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          );

          if (isTight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [avatarAndInfo, const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: segment)],
            );
          }
          return Row(children: [Expanded(child: avatarAndInfo), const SizedBox(width: 12), segment]);
        }),
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
          data: (state) {
            final Widget rosterWidget = Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Mark Roster Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('Updates live attendance logs & percentages.', style: TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                    const SizedBox(height: 20),
                    isMobile
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.employees.length,
                            itemBuilder: (context, idx) => _buildRosterItem(context, ref, state, state.employees[idx]),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: state.employees.length,
                              itemBuilder: (context, idx) => _buildRosterItem(context, ref, state, state.employees[idx]),
                            ),
                          ),
                  ],
                ),
              ),
            );

            final recentAttendance = [...state.attendance]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

            final Widget logWidget = Padding(
              padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Attendance Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      if (recentAttendance.isEmpty)
                        const Text('No attendance records yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentAttendance.length > 30 ? 30 : recentAttendance.length,
                          itemBuilder: (context, idx) {
                            final rec = recentAttendance[idx];
                            final emp = state.employeeById(rec.employeeId);
                            Color statusColor = AppTheme.accentGreen;
                            if (rec.status == 'LATE') statusColor = AppTheme.accentAmber;
                            if (rec.status == 'ABSENT') statusColor = AppTheme.accentRed;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                              title: Text(emp?.name ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              subtitle: Text(_formatDate(rec.date), style: const TextStyle(fontSize: 10, color: AppTheme.slateLight)),
                              trailing: Text(rec.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );

            if (isMobile) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [rosterWidget, const SizedBox(height: 20), logWidget]),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(flex: 1, child: rosterWidget), Expanded(flex: 1, child: logWidget)],
            );
          },
        );
      },
        );
      },
    );
  }
}
