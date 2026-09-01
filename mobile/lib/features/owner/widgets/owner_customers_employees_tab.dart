import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../salon_state.dart';

// --- CUSTOMERS TAB ---

class OwnerCustomersTab extends StatefulWidget {
  const OwnerCustomersTab({super.key});

  @override
  State<OwnerCustomersTab> createState() => _OwnerCustomersTabState();
}

class _OwnerCustomersTabState extends State<OwnerCustomersTab> {
  final _searchController = TextEditingController();
  Customer? _selectedCustomer;
  String _filterStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String status = 'Green';

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
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Customer Status Roster'),
                  items: ['Green', 'Yellow', 'Red'].map((st) {
                    return DropdownMenuItem(value: st, child: Text(st));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        status = val;
                      });
                    }
                  },
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
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                ref.read(salonStateProvider.notifier).addCustomer(
                      name,
                      phoneController.text.trim(),
                      emailController.text.trim(),
                      status,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer "$name" added successfully!')),
                );
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);
        
        // Filter and Search Customers
        final query = _searchController.text.toLowerCase().trim();
        final filteredCustomers = state.customers.where((cust) {
          final matchesSearch = cust.name.toLowerCase().contains(query) ||
              cust.phone.contains(query) ||
              cust.email.toLowerCase().contains(query);
          
          final matchesFilter = _filterStatus == 'All' || cust.status == _filterStatus;
          
          return matchesSearch && matchesFilter;
        }).toList();

        final Widget listColumn = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: isMobile 
                ? BorderRadius.circular(16)
                : const BorderRadius.horizontal(right: Radius.circular(16)),
            side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
          color: Colors.white,
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
                      icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF6750A4)),
                      tooltip: 'Add Customer',
                      onPressed: () => _showAddCustomerDialog(context, ref),
                    ),
                    Text(
                      'Total: ${state.totalCustomersDisplayCount}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or email...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // Status Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Green', 'Yellow', 'Red'].map((status) {
                      final isSel = _filterStatus == status;
                      Color color = Colors.grey.shade600;
                      if (status == 'Green') color = Colors.green;
                      if (status == 'Yellow') color = Colors.orange;
                      if (status == 'Red') color = Colors.red;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSel,
                          selectedColor: color.withOpacity(0.12),
                          labelStyle: TextStyle(
                            color: isSel ? color : Colors.grey.shade600,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _filterStatus = status;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Customers List
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final cust = filteredCustomers[index];
                      final isSel = _selectedCustomer?.id == cust.id;
                      Color statusColor = Colors.green;
                      if (cust.status == 'Yellow') statusColor = Colors.orange;
                      if (cust.status == 'Red') statusColor = Colors.red;

                      return Card(
                        elevation: 0,
                        color: isSel ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSel ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(cust.avatarUrl),
                            backgroundColor: Colors.grey.shade200,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cust.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${cust.phone} • ${cust.visitCount} visits',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedCustomer = cust;
                            });
                          },
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCustomer = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Customers Directory'),
                  ),
                ),
                Expanded(child: _buildCustomerProfile(ref)),
              ],
            );
          }
          return listColumn;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: listColumn),
            Expanded(
              flex: 1,
              child: _selectedCustomer == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_pin_circle_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Select a customer to view profile details'),
                        ],
                      ),
                    )
                  : _buildCustomerProfile(ref),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerProfile(WidgetRef ref) {
    // Reload state customer details because customer lists can update reactive counts
    final freshState = ref.watch(salonStateProvider);
    final cust = freshState.customers.firstWhere(
      (c) => c.id == _selectedCustomer!.id,
      orElse: () => _selectedCustomer!,
    );

    Color statusColor = Colors.green;
    String statusDesc = 'Active / High Engagement';
    if (cust.status == 'Yellow') {
      statusColor = Colors.orange;
      statusDesc = 'At Risk / Medium Inactivity';
    } else if (cust.status == 'Red') {
      statusColor = Colors.red;
      statusDesc = 'Churn Risk / High Inactivity';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(cust.avatarUrl),
                    radius: 36,
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cust.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cust.email,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cust.phone,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Customer Status Card
          Card(
            elevation: 0,
            color: statusColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: statusColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${cust.status} Roster',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        statusDesc,
                        style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Summary Card
          Row(
            children: [
              Expanded(
                child: _buildProfileStatCard('Total Spent', '₹${cust.totalSpent.toStringAsFixed(0)}', Icons.payment, Colors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProfileStatCard('Visit Count', '${cust.visitCount} visits', Icons.event_note, Colors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildProfileStatCard('Last Visit', cust.lastVisitDate, Icons.schedule, Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Services Taken Chips
          const Text(
            'Services Availed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cust.servicesTaken.map((service) {
              return Chip(
                label: Text(
                  service,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Colors.grey.shade50,
                side: BorderSide(color: Colors.grey.shade200),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Visit History List
          const Text(
            'Visit History Log',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cust.visitHistory.length,
            itemBuilder: (context, idx) {
              final visit = cust.visitHistory[idx];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: const Icon(Icons.check_circle_outline, color: Colors.indigo, size: 20),
                  ),
                  title: Text(
                    visit.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                    visit.date,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${visit.amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            visit.rating.toString(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
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
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
  Employee? _selectedEmployee;

  void _showAddEmployeeDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController(text: 'Hair Stylist');
    final salaryController = TextEditingController(text: '25000');
    final commController = TextEditingController(text: '15');
    final targetController = TextEditingController(text: '60000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 10),
            Text('Create Employee Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Jamie Davis'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Login Email *', hintText: 'e.g. jamie@salon.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+91 98765 43210'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Stylist Role', hintText: 'Senior Stylist / Colorist'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: salaryController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Base Retainer (Rs.)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: commController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Commission (%)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Target (Rs.)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              if (name.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Email are required.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              final salary = double.tryParse(salaryController.text) ?? 25000;
              final comm = double.tryParse(commController.text) ?? 15;
              final target = double.tryParse(targetController.text) ?? 60000;

              ref.read(salonStateProvider.notifier).addEmployee(
                    name,
                    roleController.text.trim(),
                    email,
                    phoneController.text.trim(),
                    salary,
                    comm,
                    target,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Account created for $name with default password "password123".'),
                  backgroundColor: AppTheme.accentGreen,
                ),
              );
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, Employee emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Employee Password'),
        content: Text('Are you sure you want to reset password for "${emp.name}" to default "password123"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password for ${emp.name} reset to "password123".'),
                  backgroundColor: AppTheme.accentGreen,
                ),
              );
            },
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

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
                  const Text(
                    'Staff & Stylists',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEmployeeDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Staff', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Active on Shift: ${state.employees.where((e) => e.status == 'Present').length} / ${state.employees.length}',
                style: const TextStyle(color: AppTheme.slateLight, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: state.employees.length,
                  itemBuilder: (context, idx) {
                    final emp = state.employees[idx];
                    final isSel = _selectedEmployee?.id == emp.id;
                    Color statusColor = AppTheme.accentGreen;
                    if (emp.status == 'Late') statusColor = Colors.orange;
                    if (emp.status == 'Absent') statusColor = Colors.grey;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryBlue : AppTheme.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            emp.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 12),
                          ),
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
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                emp.status,
                                style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${emp.role} • ${emp.email}',
                          style: const TextStyle(color: AppTheme.slateLight, fontSize: 11),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedEmployee = emp;
                          });
                        },
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedEmployee = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Staff List'),
                  ),
                ),
                Expanded(child: _buildEmployeeProfile(ref)),
              ],
            );
          }
          return listColumn;
        }

        return Row(
          children: [
            Expanded(flex: 1, child: listColumn),
            Expanded(
              flex: 1,
              child: _selectedEmployee == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 56, color: AppTheme.slateLight),
                          SizedBox(height: 12),
                          Text('Select an employee to view details & metrics', style: TextStyle(color: AppTheme.slateMedium)),
                        ],
                      ),
                    )
                  : _buildEmployeeProfile(ref),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeProfile(WidgetRef ref) {
    final state = ref.watch(salonStateProvider);
    final emp = state.employees.firstWhere(
      (e) => e.id == _selectedEmployee!.id,
      orElse: () => _selectedEmployee!,
    );

    final double targetProgressRatio = emp.dailyTarget > 0 ? (emp.completedTarget / emp.dailyTarget) : 0.75;
    final double salaryWithComm = emp.currentSalary + (emp.completedTarget * (emp.commissionRate / 100));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(
                    emp.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark),
                      ),
                      Text(
                        emp.role,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${emp.phone}',
                        style: const TextStyle(color: AppTheme.slateLight, fontSize: 11),
                      ),
                      Text(
                        'Email: ${emp.email}',
                        style: const TextStyle(color: AppTheme.slateLight, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Target Tracker Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monthly Target Tracker',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark),
                    ),
                    Text(
                      '${(targetProgressRatio * 100).toStringAsFixed(0)}% Achieved',
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: targetProgressRatio > 1.0 ? 1.0 : targetProgressRatio,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Achieved: Rs. ${emp.completedTarget.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                    ),
                    Text(
                      'Target: Rs. ${emp.dailyTarget.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metrics Block
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Performance', '${emp.performanceRate.toStringAsFixed(0)}%', Icons.insights_rounded, AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard('Attendance', '${emp.attendanceRate.toStringAsFixed(0)}%', Icons.calendar_today_rounded, AppTheme.accentGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard('Base Salary', 'Rs. ${emp.currentSalary.toStringAsFixed(0)}', Icons.payments_rounded, AppTheme.slateDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard('Commission', '${emp.commissionRate.toStringAsFixed(0)}%', Icons.percent_rounded, AppTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Earnings Projection Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Projected Monthly Payout',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark),
                    ),
                    Text(
                      'Base salary + commissions accrued',
                      style: TextStyle(color: AppTheme.slateLight, fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  'Rs. ${salaryWithComm.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.accentGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Security Controls
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showResetPasswordDialog(context, emp),
              icon: const Icon(Icons.lock_reset_rounded, size: 18, color: AppTheme.primaryBlue),
              label: const Text('Reset Employee Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            val,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: AppTheme.slateLight, fontSize: 11, fontWeight: FontWeight.w600),
          ),
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
  Widget _buildRosterItem(BuildContext context, WidgetRef ref, Employee emp) {
    final segment = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Present', label: Text('P', style: TextStyle(fontSize: 10))),
        ButtonSegment(value: 'Late', label: Text('L', style: TextStyle(fontSize: 10))),
        ButtonSegment(value: 'Absent', label: Text('A', style: TextStyle(fontSize: 10))),
      ],
      selected: {emp.status},
      onSelectionChanged: (Set<String> newSelection) {
        ref.read(salonStateProvider.notifier).updateEmployeeAttendance(
              emp.id,
              newSelection.first,
            );

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance updated for ${emp.name} to ${newSelection.first}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: LayoutBuilder(builder: (context, cons) {
          final isTight = cons.maxWidth < 480;
          final Widget avatarAndInfo = Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(emp.avatarUrl),
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emp.role,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          if (isTight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                avatarAndInfo,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: segment),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: avatarAndInfo),
              const SizedBox(width: 12),
              segment,
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        final Widget rosterWidget = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: isMobile 
                ? BorderRadius.circular(16)
                : const BorderRadius.horizontal(right: Radius.circular(16)),
            side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mark Roster Today',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updates live attendance logs & percentages.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
                const SizedBox(height: 20),
                isMobile 
                    ? ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.employees.length,
                        itemBuilder: (context, idx) => _buildRosterItem(context, ref, state.employees[idx]),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: state.employees.length,
                          itemBuilder: (context, idx) => _buildRosterItem(context, ref, state.employees[idx]),
                        ),
                      ),
              ],
            ),
          ),
        );

        final Widget calendarWidget = Padding(
          padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(24.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Attendance Summary',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Roster logs for July 2026',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'July 2026',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Custom Calendar painting/grid
                  _buildCustomCalendarGrid(),
                  const SizedBox(height: 24),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem('Present', Colors.green),
                      _buildLegendItem('Late', Colors.orange),
                      _buildLegendItem('Absent', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                rosterWidget,
                const SizedBox(height: 20),
                calendarWidget,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: rosterWidget,
            ),
            Expanded(
              flex: 1,
              child: calendarWidget,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCustomCalendarGrid() {
    // July 2026 starts on Wednesday (3). So 3 blank items at the start.
    // 31 days total.
    const daysInMonth = 31;
    const offset = 3;
    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Weekdays header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekdayNames.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: daysInMonth + offset,
          itemBuilder: (context, index) {
            if (index < offset) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - offset + 1;
            
            // Hardcode some mock dots for calendar dates
            Color dotColor = Colors.green;
            // Saturdays and Sundays have few absents, weekdays have mixed
            if (dayNumber % 7 == 0 || dayNumber == 12 || dayNumber == 24) {
              dotColor = Colors.orange; // Late
            } else if (dayNumber % 11 == 0 || dayNumber == 6) {
              dotColor = Colors.red; // Absent
            }

            // Highlight "Today" (July 15, 2026)
            final isToday = dayNumber == 15;

            return Container(
              decoration: BoxDecoration(
                color: isToday ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                    : Border.all(color: Colors.grey.shade100, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNumber.toString(),
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                      color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
