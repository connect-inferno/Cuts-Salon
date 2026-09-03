import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../data/app_data_provider.dart';
import '../../data/models.dart';
import '../auth/auth_provider.dart';
import '../../firebase/salon_auth.dart';
import '../../widgets/app_page_switcher.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/searchable_picker.dart';

const double _kMobileBreakpoint = 800;

const List<String> _kMonthAbbrevs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _kWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

String _formatDate(DateTime? d) {
  if (d == null) return '-';
  return '${d.day} ${_kMonthAbbrevs[d.month - 1]} ${d.year}';
}

String _formatTime(DateTime? d) {
  if (d == null) return '-';
  final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _greeting(int hour) {
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

AttendanceRecord? _todayAttendance(AppData state, String employeeId) {
  final today = DateTime.now();
  final match = state.attendance.where((a) => a.employeeId == employeeId && a.date != null && _isSameDay(a.date!, today));
  return match.isEmpty ? null : match.first;
}

String _targetTypeLabel(String type) {
  switch (type) {
    case 'SERVICE_VOLUME':
      return 'Service Revenue Target';
    case 'PRODUCT_SALES_COUNT':
      return 'Product Sales Count Target';
    default:
      return type;
  }
}

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
    'Discount Requests',
  ];

  final List<IconData> _tabIcons = [
    PhosphorIconsRegular.house,
    PhosphorIconsRegular.calendarBlank,
    PhosphorIconsRegular.usersThree,
    PhosphorIconsRegular.receipt,
    PhosphorIconsRegular.wallet,
    PhosphorIconsRegular.chartLineUp,
    PhosphorIconsRegular.userCircle,
    PhosphorIconsRegular.tag,
  ];

  Widget _buildSidebar(BuildContext context, EmployeeProfile empProfile, {required bool isMobile}) {
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
                    PhosphorIconsRegular.storefront,
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
              icon: const Icon(PhosphorIconsRegular.signOut, size: 16, color: AppTheme.slateLight),
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
    final auth = ref.watch(authControllerProvider);
    final asyncData = ref.watch(appDataProvider);

    return asyncData.when(
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (err, st) => Scaffold(
        body: AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      ),
      data: (state) {
        final empProfile = state.employeeById(auth.employeeProfileId ?? '');
        if (empProfile == null) {
          return const Scaffold(body: Center(child: Text('Employee profile not found.')));
        }
        return _buildScaffold(context, empProfile, state);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, EmployeeProfile empProfile, AppData state) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

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
                      PhosphorIconsRegular.storefront,
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
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 65,
                  child: Row(
                    children: [
                      _buildBottomNavItem(icon: PhosphorIconsRegular.house, label: 'Dashboard', tabIndex: 0),
                      _buildBottomNavItem(icon: PhosphorIconsRegular.receipt, label: 'Billing', tabIndex: 3),
                      _buildBottomNavItem(icon: PhosphorIconsRegular.usersThree, label: 'Customers', tabIndex: 2),
                      _buildBottomNavItem(icon: PhosphorIconsRegular.calendarBlank, label: 'Attendance', tabIndex: 1),
                      _buildBottomNavItem(icon: PhosphorIconsRegular.wallet, label: 'Earnings', tabIndex: 4),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: isMobile
            ? _buildEmployeeTabContent(empProfile, state)
            : Row(
                children: [
                  _buildSidebar(context, empProfile, isMobile: false),
                  Expanded(
                    child: _buildEmployeeTabContent(empProfile, state),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBottomNavItem({required IconData icon, required String label, required int tabIndex}) {
    final isSelected = _activeTabIndex == tabIndex;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTabIndex = tabIndex),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20, color: isSelected ? AppTheme.primaryBlue : AppTheme.slateLight),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTabContent(EmployeeProfile profile, AppData state) {
    return AppPageSwitcher(child: _buildEmployeeTabContentRaw(profile, state));
  }

  Widget _buildEmployeeTabContentRaw(EmployeeProfile profile, AppData state) {
    switch (_activeTabIndex) {
      case 0:
        return _EmployeeDashboardTab(
          profile: profile,
          state: state,
          onTabSelected: (idx) {
            setState(() {
              _activeTabIndex = idx;
            });
          },
        );
      case 1:
        return _EmployeeAttendanceTab(profile: profile, state: state);
      case 2:
        return const _EmployeeCustomersTab();
      case 3:
        return _EmployeeBillingTab(profile: profile);
      case 4:
        return _EmployeeSalaryTab(profile: profile, state: state);
      case 5:
        return _EmployeeTargetTab(profile: profile, state: state);
      case 6:
        return _EmployeeProfileTab(profile: profile, state: state);
      case 7:
        return _EmployeeDiscountRequestsTab(profile: profile, state: state);
      default:
        return const Center(key: ValueKey('fallback'), child: Text('Coming Soon Screen'));
    }
  }
}

// --- EMPLOYEE DASHBOARD TAB ---

class _EmployeeDashboardTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final AppData state;
  final ValueChanged<int> onTabSelected;

  const _EmployeeDashboardTab({required this.profile, required this.state, required this.onTabSelected});

  Future<void> _toggleClock(BuildContext context, WidgetRef ref, bool isClockedIn) async {
    try {
      if (isClockedIn) {
        await ref.read(appDataProvider.notifier).clockOut();
      } else {
        await ref.read(appDataProvider.notifier).clockIn();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isClockedIn ? 'Clocked out successfully.' : 'Clocked in successfully!'),
            backgroundColor: isClockedIn ? AppTheme.accentAmber : AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockOut == null;
    final firstName = profile.name.split(' ').first;

    final myBills = state.bills.where((b) => b.items.any((i) => i.employeeId == profile.id)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final recentBills = myBills.take(3).toList();

    final activeTargets = state.salesTargets.where((t) => t.employeeId == profile.id && t.status == 'ACTIVE');
    final target = activeTargets.isEmpty ? null : activeTargets.first;

    final greetingCard = Container(
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
                      'Good ${_greeting(now.hour)}, $firstName',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slateDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today is ${_kWeekdays[now.weekday - 1]}, ${_kMonthAbbrevs[now.month - 1]} ${now.day}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.slateLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                  PhosphorIconsRegular.clock,
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
                              onPressed: () => _toggleClock(context, ref, isClockedIn),
                              icon: Icon(
                                isClockedIn ? PhosphorIconsRegular.signOut : PhosphorIconsRegular.signIn,
                                size: 16,
                              ),
                              label: Text(
                                isClockedIn ? 'Clock Out' : 'Clock In',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isClockedIn ? AppTheme.slateDark : AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: (isClockedIn ? AppTheme.slateDark : AppTheme.primaryBlue).withValues(alpha: 0.3),
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
    );

    final billingBanner = InkWell(
                onTap: () => onTabSelected(3),
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
                          PhosphorIconsRegular.shoppingBag,
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
                          PhosphorIconsRegular.arrowRight,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
    );

    final recentBillsCard = Container(
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
                            Icon(PhosphorIconsRegular.clockCounterClockwise, size: 18, color: AppTheme.slateMedium),
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
                    if (recentBills.isEmpty)
                      const Text('No bills yet. Start billing to see your activity here.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else
                      for (int i = 0; i < recentBills.length; i++) ...[
                        if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 16),
                        _buildBillItem(recentBills[i], profile.id),
                      ],
                  ],
                ),
    );

    final targetCard = Container(
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
                        Icon(PhosphorIconsRegular.chartLineUp, size: 18, color: AppTheme.slateMedium),
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
                    if (target == null)
                      const Text('No active target set. Ask your manager to set one.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Achieved',
                                style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                target.progressValue.toStringAsFixed(0),
                                style: const TextStyle(
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
                              const Text(
                                'Target',
                                style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                target.targetValue.toStringAsFixed(0),
                                style: const TextStyle(
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
                        child: LinearProgressIndicator(
                          value: target.progressFraction,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(target.progressFraction * 100).toStringAsFixed(0)}% Completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slateLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.lightbulb,
                              size: 18,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                target.progressValue >= target.targetValue
                                    ? 'Target achieved! Great work this period.'
                                    : 'You need ${(target.targetValue - target.progressValue).toStringAsFixed(0)} more to hit your target.',
                                style: const TextStyle(
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
                  ],
                ),
    );

    final discountCard = Builder(builder: (context) {
                final myRequests = state.discountRequests;
                final pendingCount = myRequests.where((r) => r.status == 'PENDING').length;
                return Container(
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
                              Icon(PhosphorIconsRegular.tag, size: 18, color: AppTheme.slateMedium),
                              SizedBox(width: 8),
                              Text(
                                'Discount Requests',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => onTabSelected(7),
                            child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pendingCount == 0
                            ? 'Need a bigger discount approved than you can give yourself? Ask your manager.'
                            : '$pendingCount request${pendingCount == 1 ? '' : 's'} waiting on your manager.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                      ),
                    ],
                  ),
                );
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        // >=900 mirrors _kMobileBreakpoint's sidebar cutoff in the shell -
        // below that this tab already has the full window width, and the
        // single-column layout (designed for that width) is already right.
        final isWide = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0, vertical: 20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1100 : 600),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [greetingCard, const SizedBox(height: 16), billingBanner, const SizedBox(height: 16), recentBillsCard],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [targetCard, const SizedBox(height: 16), discountCard],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        greetingCard,
                        const SizedBox(height: 14),
                        billingBanner,
                        const SizedBox(height: 16),
                        recentBillsCard,
                        const SizedBox(height: 16),
                        targetCard,
                        const SizedBox(height: 16),
                        discountCard,
                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillItem(Bill bill, String myEmployeeId) {
    final myItems = bill.items.where((i) => i.employeeId == myEmployeeId).toList();
    final myTotal = myItems.fold<double>(0, (s, i) => s + (i.unitPrice * i.quantity) - i.discountAmount);
    final serviceNames = myItems.map((i) => i.serviceName ?? i.productName ?? 'Item').join(', ');
    final name = bill.customerName ?? 'Customer';
    final initials = name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join();
    final now = DateTime.now();
    final time = (bill.createdAt != null && _isSameDay(bill.createdAt!, now)) ? _formatTime(bill.createdAt) : _formatDate(bill.createdAt);

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primaryLight,
          child: Text(
            initials,
            style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold),
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
                  const Icon(PhosphorIconsRegular.scissors, size: 11, color: AppTheme.slateLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      serviceNames,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.slateLight,
                      ),
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
              'Rs. ${myTotal.toStringAsFixed(0)}',
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
}

// --- ATTENDANCE TAB ---

class _EmployeeAttendanceTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeAttendanceTab({required this.profile, required this.state});

  Future<void> _toggleClock(BuildContext context, WidgetRef ref, bool isClockedIn) async {
    try {
      if (isClockedIn) {
        await ref.read(appDataProvider.notifier).clockOut();
      } else {
        await ref.read(appDataProvider.notifier).clockIn();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isClockedIn ? 'Successfully clocked out of shift.' : 'Clock in registered successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: isClockedIn ? AppTheme.accentAmber : AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockOut == null;
    final statusLine = todayRecord == null
        ? 'Tap below to log attendance'
        : (isClockedIn ? 'You clocked in today at ${_formatTime(todayRecord.clockIn)}' : 'You clocked out today at ${_formatTime(todayRecord.clockOut)}');

    final history = [...state.attendance]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

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
                      isClockedIn ? 'SHIFT IS ACTIVE' : 'SHIFT NOT ACTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isClockedIn ? AppTheme.accentGreen : AppTheme.slateLight,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusLine,
                      style: const TextStyle(color: AppTheme.slateMedium, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    InkWell(
                      onTap: () => _toggleClock(context, ref, isClockedIn),
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
                              PhosphorIconsRegular.fingerprint,
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
              const SizedBox(height: 20),
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
                    const Text('Recent Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.slateDark)),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Text('No attendance records yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length > 14 ? 14 : history.length,
                        separatorBuilder: (context, idx) => const Divider(color: Color(0xFFF1F5F9), height: 16),
                        itemBuilder: (context, idx) {
                          final rec = history[idx];
                          Color statusColor = AppTheme.accentGreen;
                          if (rec.status == 'LATE') statusColor = AppTheme.accentAmber;
                          if (rec.status == 'ABSENT') statusColor = AppTheme.accentRed;
                          return Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_formatDate(rec.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              Text(rec.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          );
                        },
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

// --- CUSTOMERS TAB ---

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
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) {
            final q = _searchQuery.toLowerCase();
            final filtered = state.customers.where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Client Roster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
                  const SizedBox(height: 4),
                  const Text('Search clients and view their spending history.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search by client name or phone...',
                      prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: AppTheme.slateLight),
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
                              final custBills = state.bills.where((b) => b.customerId == c.id).toList()
                                ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
                              final totalSpent = custBills.fold<double>(0, (s, b) => s + b.finalAmount);
                              final lastVisit = custBills.isEmpty ? 'Never' : _formatDate(custBills.first.createdAt);

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
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                      if (c.isVip) const Icon(PhosphorIconsFill.star, color: AppTheme.accentGold, size: 14),
                                    ],
                                  ),
                                  subtitle: Text('${c.phone} • Last visit: $lastVisit', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                                  trailing: Text('Rs. ${totalSpent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
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
      },
    );
  }
}

// --- BILLING TAB ---

class _EmployeeBillingTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  const _EmployeeBillingTab({required this.profile});

  @override
  ConsumerState<_EmployeeBillingTab> createState() => _EmployeeBillingTabState();
}

class _EmployeeBillingTabState extends ConsumerState<_EmployeeBillingTab> {
  String? _selectedCustomerId;
  final Set<String> _selectedServiceIds = {};
  final Map<String, int> _selectedProductQuantities = {};
  final _serviceSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  String _paymentMethod = 'CASH';
  bool _submitting = false;

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      data: (state) => _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AppData state) {
    final selectedCustomerName = _selectedCustomerId == null ? null : _firstOrNull(state.customers.where((c) => c.id == _selectedCustomerId))?.name;
    double subtotal = 0;
    for (final id in _selectedServiceIds) {
      final svc = state.services.where((s) => s.id == id);
      if (svc.isNotEmpty) subtotal += svc.first.price;
    }
    for (final entry in _selectedProductQuantities.entries) {
      final prod = state.inventory.where((p) => p.id == entry.key);
      if (prod.isNotEmpty) subtotal += prod.first.price * entry.value;
    }
    final gstRate = state.settings?.gstRate ?? 18;
    final taxAmount = subtotal * (gstRate / 100);
    final total = subtotal + taxAmount;

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
                InkWell(
                  onTap: () async {
                    final customer = await showSearchablePicker<Customer>(
                      context: context,
                      title: 'Select Customer',
                      items: state.customers,
                      labelOf: (c) => c.name,
                      subtitleOf: (c) => c.phone,
                    );
                    if (customer != null) setState(() => _selectedCustomerId = customer.id);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedCustomerName ?? 'Choose client...',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: selectedCustomerName == null ? AppTheme.slateLight : AppTheme.slateDark),
                          ),
                        ),
                        const Icon(PhosphorIconsRegular.caretDown, size: 16, color: AppTheme.slateLight),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Services Rendered', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.slateMedium)),
                const SizedBox(height: 8),
                if (state.services.isEmpty)
                  const Text('No services in catalog yet.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight))
                else ...[
                  if (state.services.length > 5) ...[
                    TextField(
                      controller: _serviceSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Search services...', prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18), isDense: true),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Builder(builder: (context) {
                    final query = _serviceSearchController.text.toLowerCase().trim();
                    final filtered = query.isEmpty ? state.services : state.services.where((s) => s.name.toLowerCase().contains(query)).toList();
                    if (filtered.isEmpty) {
                      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No services match your search.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight)));
                    }
                    return Column(
                      children: filtered.map((s) {
                        final isSel = _selectedServiceIds.contains(s.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('Rs. ${s.price.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                          value: isSel,
                          activeColor: AppTheme.primaryBlue,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedServiceIds.add(s.id);
                              } else {
                                _selectedServiceIds.remove(s.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text('Products Sold', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.slateMedium)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final sellable = state.inventory.where((p) => p.stockCount > 0).toList();
                  if (sellable.isEmpty) {
                    return const Text('No in-stock products to sell right now.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight));
                  }
                  final query = _productSearchController.text.toLowerCase().trim();
                  final filtered = query.isEmpty ? sellable : sellable.where((p) => p.name.toLowerCase().contains(query)).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sellable.length > 5) ...[
                        TextField(
                          controller: _productSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(hintText: 'Search products...', prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18), isDense: true),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (filtered.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No products match your search.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight)))
                      else
                        ...filtered.map((prod) {
                          final qty = _selectedProductQuantities[prod.id] ?? 0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text('Rs. ${prod.price.toStringAsFixed(0)} • ${prod.stockCount} in stock', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                            trailing: qty == 0
                                ? OutlinedButton(
                                    onPressed: () => setState(() => _selectedProductQuantities[prod.id] = 1),
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12)),
                                    child: const Text('Add', style: TextStyle(fontSize: 11)),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(PhosphorIconsRegular.minusCircle, size: 20),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(() {
                                          if (qty <= 1) {
                                            _selectedProductQuantities.remove(prod.id);
                                          } else {
                                            _selectedProductQuantities[prod.id] = qty - 1;
                                          }
                                        }),
                                      ),
                                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      IconButton(
                                        icon: const Icon(PhosphorIconsRegular.plusCircle, size: 20),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: qty >= prod.stockCount ? null : () => setState(() => _selectedProductQuantities[prod.id] = qty + 1),
                                      ),
                                    ],
                                  ),
                          );
                        }),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.slateMedium)),
                const SizedBox(height: 8),
                Row(
                  children: ['CASH', 'CARD', 'UPI'].map((method) {
                    final isSel = _paymentMethod == method;
                    Color color = AppTheme.primaryBlue;
                    if (method == 'CASH') color = AppTheme.accentAmber;
                    if (method == 'CARD') color = Colors.deepPurple;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () => setState(() => _paymentMethod = method),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel ? color.withValues(alpha: 0.12) : Colors.transparent,
                              border: Border.all(color: isSel ? color : AppTheme.borderStrong, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: Text(method, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? color : AppTheme.slateMedium, fontSize: 12))),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 28, color: AppTheme.borderSubtle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(color: AppTheme.slateMedium, fontSize: 13)),
                    Text('Rs. ${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GST (${gstRate.toStringAsFixed(0)}%)', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                    Text('Rs. ${taxAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.slateDark)),
                    Text('Rs. ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.primaryBlue)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_selectedCustomerId == null || (_selectedServiceIds.isEmpty && _selectedProductQuantities.isEmpty) || _submitting) ? null : () => _submit(context, state),
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Complete & Generate Bill'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, AppData state) async {
    setState(() => _submitting = true);
    try {
      final items = [
        ..._selectedServiceIds.map((id) => BillItemInput(type: 'SERVICE', serviceId: id, employeeId: widget.profile.id, quantity: 1)),
        ..._selectedProductQuantities.entries.map((e) => BillItemInput(type: 'PRODUCT', inventoryItemId: e.key, employeeId: widget.profile.id, quantity: e.value)),
      ];
      final bill = await ref.read(appDataProvider.notifier).createBill(
            customerId: _selectedCustomerId!,
            branchId: widget.profile.branchId,
            paymentMethod: _paymentMethod,
            items: items,
          );

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(PhosphorIconsRegular.checkCircle, color: AppTheme.accentGreen, size: 28), SizedBox(width: 8), Text('Bill Generated')]),
          content: Text('Invoice ${bill.invoiceNumber} created.\nTotal: Rs. ${bill.finalAmount.toStringAsFixed(0)} via $_paymentMethod.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedCustomerId = null;
                  _selectedServiceIds.clear();
                  _selectedProductQuantities.clear();
                });
              },
              child: const Text('OK'),
            ),
          ],
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
}

// --- SALARY TAB ---

class _EmployeeSalaryTab extends StatelessWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeSalaryTab({required this.profile, required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final pendingCommission = state.commissions
        .where((c) => c.employeeId == profile.id && c.status == 'PENDING')
        .fold<double>(0, (s, c) => s + c.amount);

    final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final lateDays = monthAttendance.where((a) => a.status == 'LATE').length;
    final penaltyRate = state.settings?.lateAttendancePenalty ?? 0;
    final deductions = lateDays * penaltyRate;
    final estimatedNet = profile.baseSalary + pendingCommission - deductions;

    final history = [...state.salaryRecords]..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });

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
              const Text('Live payout estimate for the current month.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
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
                    _buildSalaryRow('Base Monthly Retainer', 'Rs. ${profile.baseSalary.toStringAsFixed(0)}'),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    _buildSalaryRow('Pending Commission', 'Rs. ${pendingCommission.toStringAsFixed(0)}'),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    _buildSalaryRow(
                      'Attendance Deductions${lateDays > 0 ? ' ($lateDays late)' : ''}',
                      '-Rs. ${deductions.toStringAsFixed(0)}',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Payout (Estimated)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.slateDark)),
                        Text('Rs. ${estimatedNet.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.accentGreen)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                    const Text('Payout History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.slateDark)),
                    const SizedBox(height: 12),
                    if (history.isEmpty)
                      const Text('No finalized payouts yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length,
                        separatorBuilder: (context, idx) => const Divider(color: Color(0xFFF1F5F9), height: 16),
                        itemBuilder: (context, idx) {
                          final rec = history[idx];
                          final isPaid = rec.status == 'PAID';
                          return Row(
                            children: [
                              Expanded(
                                child: Text('${_kMonthAbbrevs[rec.month - 1]} ${rec.year}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              Text('Rs. ${rec.totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: isPaid ? AppTheme.accentGreenBg : AppTheme.borderSubtle, borderRadius: BorderRadius.circular(4)),
                                child: Text(rec.status, style: TextStyle(color: isPaid ? AppTheme.accentGreen : AppTheme.slateLight, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        },
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

// --- SALES TARGET TAB ---

class _EmployeeTargetTab extends StatelessWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeTargetTab({required this.profile, required this.state});

  @override
  Widget build(BuildContext context) {
    final targets = [...state.salesTargets]..sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));

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
              const Text('Track your revenue quotas set by your manager.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),
              if (targets.isEmpty)
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
                  padding: const EdgeInsets.all(32.0),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(PhosphorIconsRegular.flag, size: 40, color: AppTheme.borderSubtle),
                        SizedBox(height: 12),
                        Text('No sales targets set yet.', style: TextStyle(color: AppTheme.slateMedium, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Your manager can set one from the Employees tab.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                for (int i = 0; i < targets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildTargetCard(targets[i]),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(SalesTarget target) {
    Color statusColor = AppTheme.primaryBlue;
    if (target.status == 'ACHIEVED') statusColor = AppTheme.accentGreen;
    if (target.status == 'FAILED') statusColor = AppTheme.accentRed;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(_targetTypeLabel(target.type), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(target.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_formatDate(target.startDate)} — ${_formatDate(target.endDate)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Achieved:', style: TextStyle(color: AppTheme.slateMedium)),
              Text(target.progressValue.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target Quota:', style: TextStyle(color: AppTheme.slateMedium)),
              Text(target.targetValue.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- PROFILE TAB ---

class _EmployeeProfileTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeProfileTab({required this.profile, required this.state});

  @override
  ConsumerState<_EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends ConsumerState<_EmployeeProfileTab> {
  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(PhosphorIconsRegular.lockKey, color: AppTheme.primaryBlue),
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
                decoration: const InputDecoration(labelText: 'New Password', hintText: 'min 8 characters'),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (newPassController.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('New password must be at least 8 characters long.'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      if (newPassController.text != confirmPassController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('New passwords do not match.'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final auth = ref.read(authControllerProvider);
                        final app = SalonAuth.currentApp(auth.salonId!);
                        if (app == null) throw Exception('No initialized Firebase app for salon "${auth.salonId}"');
                        await SalonAuth.changeOwnPassword(app, currentPassword: currentPassController.text, newPassword: newPassController.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppTheme.accentGreen),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final state = widget.state;
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockOut == null;

    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    final activeTargets = state.salesTargets.where((t) => t.employeeId == profile.id && t.status == 'ACTIVE');
    final target = activeTargets.isEmpty ? null : activeTargets.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Employee Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.slateDark, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your profile, shift information, and account settings.',
                style: TextStyle(color: AppTheme.slateLight, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
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
                            color: isClockedIn ? AppTheme.accentGreen : AppTheme.textMuted,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, color: AppTheme.slateDark)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(20)),
                          child: Text(profile.roleTitle, style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: isClockedIn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            isClockedIn ? '● Active on Shift' : '○ Off Duty',
                            style: TextStyle(color: isClockedIn ? AppTheme.accentGreen : AppTheme.slateLight, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Attendance', '${attendancePct.toStringAsFixed(0)}%', AppTheme.accentGreen),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatColumn('Target Progress', target == null ? '—' : '${(target.progressFraction * 100).toStringAsFixed(0)}%', AppTheme.primaryBlue),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatColumn('Commission', '${profile.serviceCommissionPct.toStringAsFixed(0)}%', AppTheme.slateDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Work & Compensation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                    const SizedBox(height: 16),
                    _buildInfoTile(PhosphorIconsRegular.storefront, 'Assigned Branch', profile.branchName ?? '-'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(PhosphorIconsRegular.money, 'Base Retainer', 'Rs. ${profile.baseSalary.toStringAsFixed(0)} / month'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(PhosphorIconsRegular.percent, 'Service Commission', '${profile.serviceCommissionPct.toStringAsFixed(0)}% per service item'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(PhosphorIconsRegular.percent, 'Product Commission', '${profile.productCommissionPct.toStringAsFixed(0)}% per product item'),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(PhosphorIconsRegular.flag, 'Monthly Target', target == null ? 'Not set' : target.targetValue.toStringAsFixed(0)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                    const SizedBox(height: 16),
                    _buildInfoTile(PhosphorIconsRegular.envelopeSimple, 'Login Email', profile.email),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildInfoTile(PhosphorIconsRegular.phone, 'Contact Phone', profile.phone),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security & Session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: () => _showChangePasswordDialog(context, ref),
                        icon: const Icon(PhosphorIconsRegular.key, size: 18, color: AppTheme.primaryBlue),
                        label: const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryLight, width: 1.5), backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3)),
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
                        icon: const Icon(PhosphorIconsRegular.signOut, size: 18, color: AppTheme.accentRed),
                        label: const Text('Log Out of Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentRed)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.3))),
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
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: AppTheme.slateMedium),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
          ],
        ),
      ],
    );
  }
}

// --- DISCOUNT REQUESTS TAB ---
// requestDiscount()/approveDiscountRequest()/rejectDiscountRequest() were
// already fully implemented (both REST and Firebase) in app_data_provider.dart,
// but no screen ever called requestDiscount() and nothing displayed the
// authorizedCode an approval generates - this tab is that missing UI, on both
// backends since the data layer never distinguished them.

class _EmployeeDiscountRequestsTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeDiscountRequestsTab({required this.profile, required this.state});

  void _showNewRequestDialog(BuildContext context, WidgetRef ref) {
    final discountController = TextEditingController();
    final reasonController = TextEditingController();
    final overrideController = TextEditingController();
    String? selectedBillId;
    bool submitting = false;

    final myBills = state.bills.where((b) => b.items.any((i) => i.employeeId == profile.id)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(PhosphorIconsRegular.tag, color: AppTheme.primaryBlue),
              SizedBox(width: 10),
              Text('Request Discount Approval', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: selectedBillId,
                  decoration: const InputDecoration(labelText: 'Linked Bill (optional)'),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: Colors.white,
                  elevation: 3,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('General request - no bill')),
                    for (final b in myBills.take(15))
                      DropdownMenuItem<String?>(
                        value: b.id,
                        child: Text(
                          '${b.invoiceNumber} - ${b.customerName ?? "Customer"} (Rs. ${b.finalAmount.toStringAsFixed(0)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedBillId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Requested Discount (Rs.) *', hintText: 'e.g. 200'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: overrideController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Override Price (Rs., optional)', hintText: 'Leave blank unless setting a fixed final price'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Reason *', hintText: 'Why does this customer need extra discount?'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final discount = double.tryParse(discountController.text.trim());
                      if (discount == null || discount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid discount amount.'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A reason is required.'), backgroundColor: AppTheme.accentRed),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(appDataProvider.notifier).requestDiscount(
                              billId: selectedBillId,
                              requestedDiscount: discount,
                              overridePrice: double.tryParse(overrideController.text.trim()),
                              reason: reasonController.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request sent to your manager.'), backgroundColor: AppTheme.accentGreen),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.accentRed));
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppTheme.accentGreen;
      case 'REJECTED':
        return AppTheme.accentRed;
      default:
        return AppTheme.accentAmber;
    }
  }

  Widget _buildRequestCard(BuildContext context, DiscountRequest req) {
    final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
    final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;
    final statusColor = _statusColor(req.status);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(18.0),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  matchedBill != null ? '${matchedBill.customerName ?? "Customer"} • ${matchedBill.invoiceNumber}' : 'General request',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(req.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Requested Rs. ${req.requestedDiscount.toStringAsFixed(0)} off${req.overridePrice != null ? ' • override Rs. ${req.overridePrice!.toStringAsFixed(0)}' : ''}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
          ),
          const SizedBox(height: 4),
          Text(req.reason, style: const TextStyle(fontSize: 12, color: AppTheme.slateMedium)),
          const SizedBox(height: 4),
          Text(_formatDate(req.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.slateLight)),
          if (req.status == 'APPROVED' && req.authorizedCode != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.sealCheck, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Authorization Code', style: TextStyle(fontSize: 10, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
                        Text(req.authorizedCode!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.slateDark, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.copy, size: 18, color: AppTheme.slateMedium),
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: req.authorizedCode!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied.')));
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = [...state.discountRequests]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    return RefreshIndicator(
      // No real-time sync to either backend - if a manager approves this
      // elsewhere, pull-to-refresh (or the button below) is how this list
      // picks that up.
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discount Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark)),
                const SizedBox(height: 4),
                const Text('Ask your manager to approve a discount beyond what you can give.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _showNewRequestDialog(context, ref),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                    label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                if (requests.isEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
                    padding: const EdgeInsets.all(32.0),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(PhosphorIconsRegular.tag, size: 40, color: AppTheme.borderSubtle),
                          SizedBox(height: 12),
                          Text('No discount requests yet.', style: TextStyle(color: AppTheme.slateMedium, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  for (final req in requests) _buildRequestCard(context, req),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
