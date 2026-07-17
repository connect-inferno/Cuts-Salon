import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../salon_state.dart';

const double _kMobileBreakpoint = 800;

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  int _activeTabIndex = 0;

  final List<String> _tabNames = [
    'Dashboard',
    'Attendance Logs',
    'Customer Roster',
    'Quick Billing',
    'Earnings & Salary',
    'Sales Targets',
    'Personal Profile',
  ];

  final List<IconData> _tabIcons = [
    Icons.dashboard_outlined,
    Icons.lock_clock_outlined,
    Icons.people_outline,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.insights_outlined,
    Icons.account_circle_outlined,
  ];

  Widget _buildSidebar(BuildContext context, Employee empProfile, {required bool isMobile}) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile ? null : Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.spa,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Glamour Studio',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Employee Panel',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _tabNames.length,
              itemBuilder: (context, index) {
                final isSelected = _activeTabIndex == index;
                final icon = _tabIcons[index];
                final name = _tabNames[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeTabIndex = index;
                      });
                      if (isMobile) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(empProfile.avatarUrl),
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    empProfile.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final salonState = ref.watch(salonStateProvider);

    final empProfile = salonState.employees.firstWhere(
      (e) => e.email == authState.email,
      orElse: () => Employee(
        id: 'emp_temp',
        name: authState.name ?? 'Sarah Connor',
        role: 'Nail Artist & Stylist',
        email: authState.email ?? 'employee@salon.com',
        phone: '+91 98765 43214',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah',
        attendanceRate: 94.0,
        performanceRate: 89.0,
        currentSalary: 35000.0,
        commissionRate: 8.0,
        dailyTarget: 100000.0,
        completedTarget: 24000.0,
        status: 'Present',
      ),
    );

    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: Text(
                _tabNames[_activeTabIndex],
                overflow: TextOverflow.ellipsis,
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
              shape: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: SafeArea(
                child: _buildSidebar(context, empProfile, isMobile: true),
              ),
            )
          : null,
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _activeTabIndex < 5 ? _activeTabIndex : 0,
              onDestinationSelected: (idx) {
                setState(() {
                  _activeTabIndex = idx;
                });
              },
              destinations: [
                for (int i = 0; i < 5; i++)
                  NavigationDestination(
                    icon: Icon(_tabIcons[i]),
                    label: _tabNames[i].split(' ').first,
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: Container(
          color: Colors.grey.shade50,
          width: double.infinity,
          child: isMobile
              ? _buildEmployeeTabContent(empProfile, salonState)
              : Row(
                  children: [
                    _buildSidebar(context, empProfile, isMobile: false),
                    Expanded(
                      child: _buildEmployeeTabContent(empProfile, salonState),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmployeeTabContent(Employee profile, SalonState state) {
    switch (_activeTabIndex) {
      case 0:
        return _EmployeeDashboardTab(
          profile: profile,
          onTabSelected: (idx) {
            setState(() {
              _activeTabIndex = idx;
            });
          },
        );
      case 1:
        return _EmployeeAttendanceTab(profile: profile);
      case 2:
        return const _EmployeeCustomersTab();
      case 3:
        return const _EmployeeBillingTab();
      case 4:
        return _EmployeeSalaryTab(profile: profile);
      case 5:
        return _EmployeeTargetTab(profile: profile);
      case 6:
        return _EmployeeProfileTab(profile: profile);
      default:
        return const Center(child: Text('Coming Soon Screen'));
    }
  }
}

class _EmployeeDashboardTab extends StatelessWidget {
  final Employee profile;
  final ValueChanged<int> onTabSelected;

  const _EmployeeDashboardTab({required this.profile, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final double targetRemaining = profile.dailyTarget - profile.completedTarget;
    final isClockedIn = profile.status == 'Present';

    final Widget card1 = _buildMetricCard(
      'Today\'s Earnings',
      '₹${(profile.completedTarget * (profile.commissionRate / 100)).toStringAsFixed(0)}',
      'Commissions accrued',
      Icons.currency_rupee,
      Colors.green,
    );
    final Widget card2 = _buildMetricCard(
      'Sales Completed',
      '₹${profile.completedTarget.toStringAsFixed(0)}',
      'Target sales volume',
      Icons.insights,
      Colors.indigo,
    );
    final Widget card3 = _buildMetricCard(
      'Target Remaining',
      '₹${targetRemaining.toStringAsFixed(0)}',
      'To reach goal',
      Icons.flag_outlined,
      Colors.redAccent,
    );

    final Widget targetProgressCard = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Motivational Roster Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            const Text(
              'You have completed ₹24,000.\n₹76,000 more to achieve your target!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo, height: 1.5),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: profile.completedTarget / profile.dailyTarget,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => onTabSelected(5),
              child: const Text('View Target Breakdown', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );

    final Widget quickActionsCard = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions Shortcut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.alarm, size: 14),
                  label: const Text('Clock In/Out', style: TextStyle(fontSize: 11)),
                  onPressed: () => onTabSelected(1),
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_add, size: 14),
                  label: const Text('Add Client', style: TextStyle(fontSize: 11)),
                  onPressed: () => onTabSelected(2),
                ),
                ActionChip(
                  avatar: const Icon(Icons.receipt_long, size: 14),
                  label: const Text('Quick Bill', style: TextStyle(fontSize: 11)),
                  onPressed: () => onTabSelected(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hello, ${profile.name.split(" ").first}!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 20 : 24, color: Theme.of(context).colorScheme.primary),
                      ),
                      Text('Nail Salon Roster • Glamour Studio Westside', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isClockedIn ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isClockedIn ? Colors.green.shade200 : Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isClockedIn ? Colors.green : Colors.red),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isClockedIn ? 'Clocked In' : 'Clocked Out',
                          style: TextStyle(color: isClockedIn ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isMobile) ...[
                card1,
                const SizedBox(height: 16),
                card2,
                const SizedBox(height: 16),
                card3,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 16),
                    Expanded(child: card2),
                    const SizedBox(width: 16),
                    Expanded(child: card3),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (isMobile) ...[
                targetProgressCard,
                const SizedBox(height: 20),
                quickActionsCard,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: targetProgressCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 1, child: quickActionsCard),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String val, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _EmployeeAttendanceTab extends ConsumerWidget {
  final Employee profile;

  const _EmployeeAttendanceTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClockedIn = profile.status == 'Present';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Work Shift Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 4),
              const Text('Clock in when entering the salon and clock out when concluding shift.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Text(
                        isClockedIn ? 'SHIFT IS ACTIVE' : 'SHIFT NOT STARTED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isClockedIn ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isClockedIn ? 'You clocked in today at 09:12 AM' : 'Clock in to log attendance',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      InkWell(
                        onTap: () {
                          final newStatus = isClockedIn ? 'Absent' : 'Present';
                          ref.read(salonStateProvider.notifier).updateEmployeeAttendance(profile.id, newStatus);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isClockedIn ? 'Successfully clocked out of shift.' : 'Clock in registered successfully!'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: isClockedIn ? Colors.orange.shade800 : Colors.green,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isClockedIn ? Colors.red.shade50 : Colors.green.shade50,
                            border: Border.all(color: isClockedIn ? Colors.red : Colors.green, width: 4),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, color: isClockedIn ? Colors.red : Colors.green, size: 48),
                              const SizedBox(height: 8),
                              Text(
                                isClockedIn ? 'Clock Out' : 'Clock In',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isClockedIn ? Colors.red : Colors.green),
                              ),
                            ],
                          ),
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
  }
}

class _EmployeeCustomersTab extends StatefulWidget {
  const _EmployeeCustomersTab();

  @override
  State<_EmployeeCustomersTab> createState() => _EmployeeCustomersTabState();
}

class _EmployeeCustomersTabState extends State<_EmployeeCustomersTab> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        final query = _searchController.text.toLowerCase().trim();
        final filtered = state.customers.where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query)).toList();

        final Widget listWidget = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEEEEE)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Clients Directory',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('Records: ${filtered.length}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search client...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final c = filtered[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundImage: NetworkImage(c.avatarUrl)),
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${c.phone} • Last visit ${c.lastVisitDate}',
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );

        final Widget formWidget = Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Register New Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 20),
                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 16),
                const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;

                    ref.read(salonStateProvider.notifier).addCustomer(
                          name,
                          _phoneController.text.trim(),
                          '',
                          'Green',
                        );

                    _nameController.clear();
                    _phoneController.clear();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Client "$name" added to shared base successfully!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Client to Roster', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;
            if (isMobile) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    listWidget,
                    const SizedBox(height: 20),
                    formWidget,
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: listWidget),
                  const SizedBox(width: 24),
                  Expanded(flex: 1, child: formWidget),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EmployeeBillingTab extends StatefulWidget {
  const _EmployeeBillingTab();

  @override
  State<_EmployeeBillingTab> createState() => _EmployeeBillingTabState();
}

class _EmployeeBillingTabState extends State<_EmployeeBillingTab> {
  String? _clientName;
  final List<String> _selected = [];

  final List<Map<String, dynamic>> _svcs = [
    {'name': 'Premium Haircut & Styling', 'price': 1500.0},
    {'name': 'Beard Grooming & Trim', 'price': 800.0},
    {'name': 'Gel Nail Extensions', 'price': 3200.0},
    {'name': 'Deep Cleansing Facial', 'price': 2200.0},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);

        double total = 0;
        for (var n in _selected) {
          final s = _svcs.firstWhere((element) => element['name'] == n);
          total += s['price'];
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Generate Stylist Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 20),
                      const Text('Client Selector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        hint: const Text('Choose client...'),
                        initialValue: _clientName,
                        isExpanded: true,
                        items: state.customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _clientName = val;
                          });
                        },
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 20),
                      const Text('Services Rendered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 8),
                      ..._svcs.map((s) {
                        final name = s['name'] as String;
                        final isSel = _selected.contains(name);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text('₹${(s['price'] as double).toStringAsFixed(0)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11)),
                          value: isSel,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selected.add(name);
                              } else {
                                _selected.remove(name);
                              }
                            });
                          },
                        );
                      }),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(child: Text('Total Net Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Text('₹${total.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _selected.isEmpty
                            ? null
                            : () {
                                ref.read(salonStateProvider.notifier).createBill(
                                      customerName: _clientName ?? 'Walk-in Client',
                                      services: _selected,
                                      subtotal: total,
                                      discountPercent: 0.0,
                                      discountAmount: 0.0,
                                      totalAmount: total,
                                      paymentMethod: 'UPI',
                                    );

                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green),
                                        SizedBox(width: 8),
                                        Flexible(child: Text('Bill Generated Successfully')),
                                      ],
                                    ),
                                    content: Text('Invoice issued. Shared history updated with ₹${total.toStringAsFixed(0)}.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          setState(() {
                                            _selected.clear();
                                            _clientName = null;
                                          });
                                        },
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Generate Success Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmployeeSalaryTab extends StatelessWidget {
  final Employee profile;

  const _EmployeeSalaryTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final commEarned = profile.completedTarget * (profile.commissionRate / 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 4),
              const Text('Personal salary splits and commission metrics calculated for current month.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildSalaryRow('Base Monthly Salary', '₹${profile.currentSalary.toStringAsFixed(0)}', Colors.grey.shade700),
                      const Divider(height: 24),
                      _buildSalaryRow('Commission Rate', '${profile.commissionRate}%', Colors.blue),
                      const SizedBox(height: 12),
                      _buildSalaryRow('Target Sales Volume achieved', '₹${profile.completedTarget.toStringAsFixed(0)}', Colors.indigo),
                      const SizedBox(height: 12),
                      _buildSalaryRow('Commission Share Earned', '₹${commEarned.toStringAsFixed(0)}', Colors.green),
                      const Divider(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(child: Text('Total Net Earnings (Current)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Text('₹${(profile.currentSalary + commEarned).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                        ],
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
  }

  Widget _buildSalaryRow(String title, String val, Color valColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Text(val, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class _EmployeeTargetTab extends StatelessWidget {
  final Employee profile;

  const _EmployeeTargetTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Goals & Progression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MONTHLY TARGET SCORES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 16),
                      const Text(
                        'You have completed ₹24,000.\n₹76,000 more to achieve your target!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: profile.completedTarget / profile.dailyTarget,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(child: Text('Completed: ₹24,000', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Text('Goal: ₹${profile.dailyTarget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.shade200)),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Styling Tip: Offering add-on facials or pedicures to haircut clients increases commission earnings by up to 25%!',
                          style: TextStyle(color: Colors.black87, fontSize: 12),
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
  }
}

class _EmployeeProfileTab extends ConsumerWidget {
  final Employee profile;

  const _EmployeeProfileTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Work Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(profile.avatarUrl),
                        radius: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(profile.role, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 24),
                      const Divider(),
                      _buildProfileRow('Email ID', profile.email),
                      _buildProfileRow('Mobile No', profile.phone),
                      _buildProfileRow('Attendance Index', '${profile.attendanceRate.toStringAsFixed(0)}% present'),
                      _buildProfileRow('Quality Review Index', '${profile.performanceRate.toStringAsFixed(0)}% quality rating'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(authControllerProvider.notifier).logout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout Session'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }

  Widget _buildProfileRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
          Flexible(child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
