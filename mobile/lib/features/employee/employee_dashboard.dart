import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
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
    Icons.home_rounded,
    Icons.calendar_today_outlined,
    Icons.people_alt_outlined,
    Icons.receipt_long_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.insights_outlined,
    Icons.account_circle_outlined,
  ];

  Widget _buildSidebar(BuildContext context, Employee empProfile, {required bool isMobile}) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile ? null : const Border(right: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppTheme.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cuts-Salon',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.primaryBlue,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        empProfile.name,
                        style: const TextStyle(
                          color: AppTheme.slateLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.slateLight,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AppTheme.primaryBlue : AppTheme.slateMedium,
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
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: AppTheme.slateLight),
              label: const Text('Log Out', style: TextStyle(fontSize: 12, color: AppTheme.slateDark)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                side: const BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final salonState = ref.watch(salonStateProvider);

    final empProfile = salonState.employees.firstWhere(
      (e) => e.email.toLowerCase() == 'employee@salon.com',
      orElse: () => Employee(
        id: 'emp-1',
        name: 'Jamie Davis',
        role: 'Senior Stylist',
        email: 'employee@salon.com',
        phone: '+91 98765 43210',
        avatarUrl: '',
        attendanceRate: 95.0,
        performanceRate: 92.0,
        currentSalary: 25000.0,
        commissionRate: 15.0,
        dailyTarget: 60000.0,
        completedTarget: 45000.0,
        status: 'Absent',
      ),
    );

    // Map 5 Bottom Nav Bar Items (Stitch Spec)
    // 0: Dashboard, 1: Billing (index 3), 2: Customers (index 2), 3: Attendance (index 1), 4: Earnings (index 4)
    int navIndex = 0;
    if (_activeTabIndex == 3) {
      navIndex = 1;
    } else if (_activeTabIndex == 2) {
      navIndex = 2;
    } else if (_activeTabIndex == 1) {
      navIndex = 3;
    } else if (_activeTabIndex == 4) {
      navIndex = 4;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: isMobile
          ? AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cuts-Salon',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.slateMedium, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No new notifications')),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, left: 4.0),
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeTabIndex = 6); // Profile
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text(
                        empProfile.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
              shape: const Border(
                bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
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
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
              ),
              child: NavigationBar(
                backgroundColor: Colors.white,
                indicatorColor: AppTheme.primaryLight,
                selectedIndex: navIndex,
                height: 65,
                onDestinationSelected: (idx) {
                  if (idx == 0) {
                    setState(() => _activeTabIndex = 0);
                  } else if (idx == 1) {
                    setState(() => _activeTabIndex = 3); // Billing
                  } else if (idx == 2) {
                    setState(() => _activeTabIndex = 2); // Customers
                  } else if (idx == 3) {
                    setState(() => _activeTabIndex = 1); // Attendance
                  } else if (idx == 4) {
                    setState(() => _activeTabIndex = 4); // Earnings
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded, size: 20),
                    selectedIcon: Icon(Icons.home_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_rounded, size: 20),
                    selectedIcon: Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Billing',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_alt_outlined, size: 20),
                    selectedIcon: Icon(Icons.people_alt_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Customers',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined, size: 20),
                    selectedIcon: Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Attendance',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Earnings',
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
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

// --- EMPLOYEE DASHBOARD TAB (STITCH SPEC) ---

class _EmployeeDashboardTab extends ConsumerWidget {
  final Employee profile;
  final ValueChanged<int> onTabSelected;

  const _EmployeeDashboardTab({required this.profile, required this.onTabSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClockedIn = profile.status == 'Present';
    final firstName = profile.name.split(' ').first;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Greeting Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning, $firstName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slateDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Today is Tuesday, Oct 24',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.slateLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inner Attendance Card
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isClockedIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.access_time_rounded,
                                  size: 20,
                                  color: isClockedIn ? AppTheme.accentGreen : AppTheme.accentRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Attendance Status',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.slateDark,
                                    ),
                                  ),
                                  Text(
                                    isClockedIn ? 'Clocked In (Active)' : 'Not Clocked In',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isClockedIn ? AppTheme.accentGreen : AppTheme.accentRed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final newStatus = isClockedIn ? 'Absent' : 'Present';
                                ref.read(salonStateProvider.notifier).updateEmployeeAttendance(profile.id, newStatus);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isClockedIn ? 'Clocked out successfully.' : 'Clocked in successfully!'),
                                    backgroundColor: isClockedIn ? Colors.orange.shade800 : AppTheme.accentGreen,
                                  ),
                                );
                              },
                              icon: Icon(
                                isClockedIn ? Icons.logout_rounded : Icons.login_rounded,
                                size: 16,
                              ),
                              label: Text(
                                isClockedIn ? 'Clock Out' : 'Clock In',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClockedIn ? Colors.grey.shade800 : AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. New Billing / Checkout Action Banner (Vibrant Blue)
              InkWell(
                onTap: () => onTabSelected(3), // Quick Billing
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Billing / Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Start a new transaction for walk-ins or appointments',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Recent Bills Handled Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: AppTheme.slateMedium),
                            SizedBox(width: 8),
                            Text(
                              'Recent Bills Handled',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.slateDark,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => onTabSelected(3),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bill Item 1
                    _buildBillItem(
                      initials: 'SC',
                      avatarBg: const Color(0xFFDBEAFE),
                      avatarFg: AppTheme.primaryBlue,
                      name: 'Sarah Connor',
                      service: 'Haircut & Styling',
                      amount: 'Rs. 2,500',
                      time: '10:45 AM',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),

                    // Bill Item 2
                    _buildBillItem(
                      initials: 'JR',
                      avatarBg: const Color(0xFFE2E8F0),
                      avatarFg: AppTheme.slateDark,
                      name: 'John Reese',
                      service: 'Beard Trim',
                      amount: 'Rs. 800',
                      time: '09:30 AM',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),

                    // Bill Item 3
                    _buildBillItem(
                      initials: 'EW',
                      avatarBg: AppTheme.primaryLight,
                      avatarFg: AppTheme.primaryBlue,
                      name: 'Elena Wayne',
                      service: 'Hair Color',
                      amount: 'Rs. 6,200',
                      time: 'Yesterday',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Personal Revenue Target Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.insights_rounded, size: 18, color: AppTheme.slateMedium),
                        SizedBox(width: 8),
                        Text(
                          'Personal Revenue Target',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.slateDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Achieved (Oct)',
                              style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rs. 45,000',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryBlue,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Target',
                              style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rs. 60,000',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.slateDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.75,
                        minHeight: 7,
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '75% Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slateLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tip Callout Box
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppTheme.primaryBlue,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You need Rs. 15,000 more to hit your monthly target. Suggest add on services to your next clients!',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.slateMedium,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Upcoming Appointments Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.slateMedium),
                        SizedBox(width: 8),
                        Text(
                          'Upcoming Appointments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.slateDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Appointment 1
                    _buildAppointmentItem(
                      time: '11',
                      period: 'AM',
                      clientName: 'Mike Ross',
                      serviceName: 'Haircut',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),

                    // Appointment 2
                    _buildAppointmentItem(
                      time: '01',
                      period: 'PM',
                      clientName: 'Rachel Zane',
                      serviceName: 'Highlights & Blowdry',
                    ),
                    const SizedBox(height: 12),

                    // View Full Schedule Link
                    Center(
                      child: GestureDetector(
                        onTap: () => onTabSelected(1),
                        child: const Text(
                          'View Full Schedule',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillItem({
    required String initials,
    required Color avatarBg,
    required Color avatarFg,
    required String name,
    required String service,
    required String amount,
    required String time,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: avatarBg,
          child: Text(
            initials,
            style: TextStyle(color: avatarFg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateDark,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.content_cut_rounded, size: 11, color: AppTheme.slateLight),
                  const SizedBox(width: 4),
                  Text(
                    service,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.slateLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.slateDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.slateLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentItem({
    required String time,
    required String period,
    required String clientName,
    required String serviceName,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.slateDark,
                ),
              ),
              Text(
                period,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slateLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clientName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                serviceName,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.slateLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- REMAINING SUB-TABS (ATTENDANCE, CUSTOMERS, BILLING, SALARY, TARGET, PROFILE) ---

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
              const Text('Work Shift Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              const Text('Clock in when entering the salon and clock out when concluding shift.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Text(
                      isClockedIn ? 'SHIFT IS ACTIVE' : 'SHIFT NOT STARTED',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isClockedIn ? AppTheme.accentGreen : AppTheme.slateLight,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isClockedIn ? 'You clocked in today at 09:12 AM' : 'Tap below to log attendance',
                      style: const TextStyle(color: AppTheme.slateMedium, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    InkWell(
                      onTap: () {
                        final newStatus = isClockedIn ? 'Absent' : 'Present';
                        ref.read(salonStateProvider.notifier).updateEmployeeAttendance(profile.id, newStatus);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isClockedIn ? 'Successfully clocked out of shift.' : 'Clock in registered successfully!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: isClockedIn ? Colors.orange.shade800 : AppTheme.accentGreen,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isClockedIn ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                          border: Border.all(color: isClockedIn ? AppTheme.accentRed : AppTheme.accentGreen, width: 3),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint_rounded,
                              color: isClockedIn ? AppTheme.accentRed : AppTheme.accentGreen,
                              size: 44,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isClockedIn ? 'Clock Out' : 'Clock In',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isClockedIn ? AppTheme.accentRed : AppTheme.accentGreen,
                              ),
                            ),
                          ],
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
    );
  }
}

class _EmployeeCustomersTab extends StatefulWidget {
  const _EmployeeCustomersTab();

  @override
  State<_EmployeeCustomersTab> createState() => _EmployeeCustomersTabState();
}

class _EmployeeCustomersTabState extends State<_EmployeeCustomersTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(salonStateProvider);
        final filtered = state.customers.where((c) {
          final q = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(q) || c.phone.contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Client Roster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              const Text('Search clients and view past history.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search by client name or phone...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.slateLight),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No clients found.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryLight,
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0] : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text('${c.phone} • Last visit: ${c.lastVisitDate}', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                              trailing: Text('Rs. ${c.totalSpent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeBillingTab extends ConsumerStatefulWidget {
  const _EmployeeBillingTab();

  @override
  ConsumerState<_EmployeeBillingTab> createState() => _EmployeeBillingTabState();
}

class _EmployeeBillingTabState extends ConsumerState<_EmployeeBillingTab> {
  String? _clientName;
  final Set<String> _selected = {};

  final List<Map<String, dynamic>> _svcs = [
    {'name': 'Executive Haircut', 'price': 800.0},
    {'name': 'Beard Grooming & Shape', 'price': 400.0},
    {'name': 'Organic Facial & Glow', 'price': 1500.0},
    {'name': 'Deep Scalp Massage', 'price': 600.0},
    {'name': 'Premium Hair Color', 'price': 2200.0},
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salonStateProvider);
    double subtotal = 0;
    for (final s in _svcs) {
      if (_selected.contains(s['name'])) {
        subtotal += s['price'] as double;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Generate Client Bill', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.slateDark)),
                const SizedBox(height: 18),
                const Text('Client Selector', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.slateMedium)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  hint: const Text('Choose client...'),
                  value: _clientName,
                  isExpanded: true,
                  items: state.customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) => setState(() => _clientName = val),
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 20),
                const Text('Services Rendered', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.slateMedium)),
                const SizedBox(height: 8),
                ..._svcs.map((s) {
                  final name = s['name'] as String;
                  final isSel = _selected.contains(name);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Rs. ${(s['price'] as double).toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                    value: isSel,
                    activeColor: AppTheme.primaryBlue,
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
                const Divider(height: 28, color: AppTheme.borderSubtle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.slateDark)),
                    Text('Rs. ${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.primaryBlue)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_clientName == null || _selected.isEmpty)
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bill submitted successfully for processing!'), backgroundColor: AppTheme.accentGreen),
                            );
                            setState(() {
                              _clientName = null;
                              _selected.clear();
                            });
                          },
                    child: const Text('Complete & Print Bill'),
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

class _EmployeeSalaryTab extends StatelessWidget {
  final Employee profile;

  const _EmployeeSalaryTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    const basePay = 25000.0;
    final commission = profile.completedTarget * (profile.commissionRate / 100);
    final total = basePay + commission;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings & Salary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              const Text('Monthly payout breakdown and commission ledger.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  children: [
                    _buildSalaryRow('Base Monthly Retainer', 'Rs. ${basePay.toStringAsFixed(0)}'),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    _buildSalaryRow('Commission (${profile.commissionRate.toStringAsFixed(0)}%)', 'Rs. ${commission.toStringAsFixed(0)}'),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    _buildSalaryRow('Attendance Deductions', 'Rs. 0.00'),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Payout (Estimated)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.slateDark)),
                        Text('Rs. ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.accentGreen)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium, fontWeight: FontWeight.w500)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
      ],
    );
  }
}

class _EmployeeTargetTab extends StatelessWidget {
  final Employee profile;

  const _EmployeeTargetTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final progress = profile.dailyTarget > 0 ? (profile.completedTarget / profile.dailyTarget) : 0.75;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales Targets', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
              const SizedBox(height: 4),
              const Text('Track your revenue quota for this billing cycle.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Target Progress (${(progress * 100).toStringAsFixed(0)}%)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Achieved Revenue:', style: TextStyle(color: AppTheme.slateMedium)),
                        Text('Rs. ${profile.completedTarget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Target Quota:', style: TextStyle(color: AppTheme.slateMedium)),
                        Text('Rs. ${profile.dailyTarget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeProfileTab extends ConsumerStatefulWidget {
  final Employee profile;

  const _EmployeeProfileTab({required this.profile});

  @override
  ConsumerState<_EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends ConsumerState<_EmployeeProfileTab> {
  String _upiId = 'jamie.davis@okaxis';

  void _showChangePasswordDialog(BuildContext context) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 10),
            Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password', hintText: 'Enter current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password', hintText: 'Enter new password (min 6 chars)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password', hintText: 'Re-enter new password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPassController.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters long.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match.'), backgroundColor: AppTheme.accentRed),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppTheme.accentGreen),
              );
            },
            child: const Text('Save Password'),
          ),
        ],
      ),
    );
  }

  void _showEditPayoutDialog(BuildContext context) {
    final upiController = TextEditingController(text: _upiId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Payout UPI / Bank'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your preferred UPI ID for monthly commission payouts:', style: TextStyle(fontSize: 12, color: AppTheme.slateLight)),
            const SizedBox(height: 12),
            TextField(
              controller: upiController,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                prefixIcon: Icon(Icons.qr_code_2_rounded, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (upiController.text.trim().isNotEmpty) {
                setState(() => _upiId = upiController.text.trim());
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payout info saved successfully!'), backgroundColor: AppTheme.accentGreen),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final isClockedIn = profile.status == 'Present';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              const Text(
                'Employee Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.slateDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your profile, shift information, and account settings.',
                style: TextStyle(color: AppTheme.slateLight, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // 1. Profile Overview Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryBlue,
                          child: Text(
                            profile.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isClockedIn ? AppTheme.accentGreen : Colors.grey.shade400,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppTheme.slateDark),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            profile.role,
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClockedIn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isClockedIn ? '● Active on Shift' : '○ Off Duty',
                            style: TextStyle(
                              color: isClockedIn ? AppTheme.accentGreen : AppTheme.slateLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Quick Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Attendance', '${profile.attendanceRate.toStringAsFixed(0)}%', AppTheme.accentGreen),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatColumn('Performance', '${profile.performanceRate.toStringAsFixed(0)}%', AppTheme.primaryBlue),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatColumn('Commission', '${profile.commissionRate.toStringAsFixed(0)}%', AppTheme.slateDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Work & Role Details Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Work & Compensation',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTile(Icons.badge_outlined, 'Employee ID', 'EMP-2026-084'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.storefront_outlined, 'Assigned Branch', 'Cuts-Salon • Westside Flagship'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.schedule_outlined, 'Shift Schedule', '10:00 AM – 08:00 PM (Mon–Sat)'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.payments_outlined, 'Base Retainer', 'Rs. 25,000 / month'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.percent_rounded, 'Service Commission', '${profile.commissionRate.toStringAsFixed(0)}% per bill item'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.flag_outlined, 'Monthly Target', 'Rs. ${profile.dailyTarget.toStringAsFixed(0)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Contact & Payout Details Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                          'Contact & Payout Info',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                        ),
                        InkWell(
                          onTap: () => _showEditPayoutDialog(context),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              'Edit Payout',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoTile(Icons.mail_outline_rounded, 'Login Email', profile.email),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.phone_outlined, 'Contact Phone', profile.phone),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(Icons.account_balance_wallet_outlined, 'Payout UPI', _upiId),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Security & Actions Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Security & Session',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _showChangePasswordDialog(context),
                        icon: const Icon(Icons.key_rounded, size: 18, color: AppTheme.primaryBlue),
                        label: const Text(
                          'Change Password',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryLight, width: 1.5),
                          backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Confirm Logout'),
                              content: const Text('Are you sure you want to end your current session?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(authControllerProvider.notifier).logout();
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.accentRed),
                        label: const Text(
                          'Log Out of Account',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.slateMedium),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
            ),
          ],
        ),
      ],
    );
  }
}

