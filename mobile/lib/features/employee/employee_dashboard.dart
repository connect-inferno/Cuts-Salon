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
import '../../widgets/app_dialog.dart';
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

// ─── Shared chip/badge ──────────────────────────────────────────────────────

Widget _statusBadge(String label, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );

// ─── Shell ──────────────────────────────────────────────────────────────────

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
    final salonName = ref.watch(appDataProvider).valueOrNull?.settings?.salonName ??
        ref.watch(authControllerProvider).salonName ??
        'Salon';
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
                      Text(
                        salonName,
                        style: const TextStyle(
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
    final salonName = ref.watch(appDataProvider).valueOrNull?.settings?.salonName ??
        ref.watch(authControllerProvider).salonName ??
        'Salon';

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.storefront,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      salonName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTabIndex = 6),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Text(
                        empProfile.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
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
          ? _BottomBar(
              activeIndex: _activeTabIndex,
              onTap: (i) => setState(() => _activeTabIndex = i),
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

  Widget _buildEmployeeTabContent(EmployeeProfile profile, AppData state) {
    return AppPageSwitcher(child: _buildEmployeeTabContentRaw(profile, state));
  }

  Widget _buildEmployeeTabContentRaw(EmployeeProfile profile, AppData state) {
    switch (_activeTabIndex) {
      case 0:
        return _EmployeeDashboardTab(
          profile: profile,
          state: state,
          onTabSelected: (idx) => setState(() => _activeTabIndex = idx),
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
        return _EmployeeProfileTab(profile: profile, state: state, onTabSelected: (i) => setState(() => _activeTabIndex = i));
      case 7:
        return _EmployeeDiscountRequestsTab(profile: profile, state: state);
      default:
        return const Center(key: ValueKey('fallback'), child: Text('Coming Soon Screen'));
    }
  }
}

// ─── Bottom navigation bar ──────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      (PhosphorIconsRegular.house, 'Home', 0),
      (PhosphorIconsRegular.receipt, 'Billing', 3),
      (PhosphorIconsRegular.usersThree, 'Customers', 2),
      (PhosphorIconsRegular.calendarBlank, 'Attendance', 1),
      (PhosphorIconsRegular.wallet, 'Earnings', 4),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.map((item) {
              final (icon, label, tabIndex) = item;
              final isSelected = activeIndex == tabIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(tabIndex),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryLight : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isSelected ? icon : icon,
                          size: 20,
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.slateLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.primaryBlue : AppTheme.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard home tab ─────────────────────────────────────────────────────

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
    final isClockedIn = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut == null;
    final firstName = profile.name.split(' ').first;

    final myBills = state.bills.where((b) => b.items.any((i) => i.employeeId == profile.id)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final recentBills = myBills.take(5).toList();

    // Stats
    final todayBills = myBills.where((b) => b.createdAt != null && _isSameDay(b.createdAt!, now)).toList();
    final todayCustomers = todayBills.map((b) => b.customerId).toSet().length;
    final todayRevenue = todayBills.fold<double>(0, (s, b) => s + b.finalAmount);
    final pendingCommission = state.commissions
        .where((c) => c.employeeId == profile.id && c.status == 'PENDING')
        .fold<double>(0, (s, c) => s + c.amount);

    // Greeting header
    final header = Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${_greeting(now.hour)}, $firstName',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_kWeekdays[now.weekday - 1]}, ${now.day} ${_kMonthAbbrevs[now.month - 1]} ${now.year}',
            style: const TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          // Stats row
          Row(
            children: [
              _buildStatChip(PhosphorIconsRegular.users, '$todayCustomers', 'Customers'),
              const SizedBox(width: 10),
              _buildStatChip(PhosphorIconsRegular.currencyInr, '₹${todayRevenue.toStringAsFixed(0)}', 'Revenue'),
              const SizedBox(width: 10),
              _buildStatChip(PhosphorIconsRegular.coins, '₹${pendingCommission.toStringAsFixed(0)}', 'Commission'),
              const SizedBox(width: 10),
              _buildStatChip(
                isClockedIn ? PhosphorIconsRegular.clock : PhosphorIconsRegular.clockCounterClockwise,
                isClockedIn ? 'In' : 'Out',
                'Status',
                highlight: isClockedIn,
              ),
            ],
          ),
        ],
      ),
    );

    // Clock in/out button
    final clockCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () => _toggleClock(context, ref, isClockedIn),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isClockedIn
                  ? [const Color(0xFF991B1B), const Color(0xFFB91C1C)]
                  : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isClockedIn ? const Color(0xFFB91C1C) : AppTheme.primaryBlue).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isClockedIn ? PhosphorIconsRegular.signOut : PhosphorIconsRegular.fingerprint,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClockedIn ? 'Clock Out' : 'Clock In',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isClockedIn
                          ? 'Tap to end your shift for today'
                          : 'Tap to log attendance for today',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsRegular.arrowRight, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );

    // New billing banner
    final billingBanner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () => onTabSelected(3),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIconsRegular.receipt, color: AppTheme.primaryBlue, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Billing / Checkout',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Generate a bill for a walk-in or appointment',
                      style: TextStyle(fontSize: 11, color: AppTheme.slateLight),
                    ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.arrowRight, size: 18, color: AppTheme.slateLight),
            ],
          ),
        ),
      ),
    );

    // Recent bills
    final recentCard = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
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
                const Row(
                  children: [
                    Icon(PhosphorIconsRegular.clockCounterClockwise, size: 16, color: AppTheme.slateMedium),
                    SizedBox(width: 8),
                    Text(
                      'Recent Bills Handled',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => onTabSelected(3),
                  child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (recentBills.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No bills yet. Start billing to see your activity here.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12)),
              )
            else
              for (int i = 0; i < recentBills.length; i++) ...[
                if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 16),
                _buildBillItem(recentBills[i], profile.id),
              ],
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          clockCard,
          const SizedBox(height: 12),
          billingBanner,
          const SizedBox(height: 16),
          recentCard,
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? AppTheme.accentGreen.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: highlight ? AppTheme.accentGreen : Colors.white70),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: highlight ? AppTheme.accentGreen : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
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
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(PhosphorIconsRegular.scissors, size: 11, color: AppTheme.slateLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      serviceNames,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.slateLight),
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
            Text('₹${myTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(fontSize: 10, color: AppTheme.slateLight)),
          ],
        ),
      ],
    );
  }
}

// ─── Attendance tab ──────────────────────────────────────────────────────────

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
    final isClockedIn = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut == null;
    final statusLine = todayRecord == null
        ? 'Tap below to log attendance'
        : (isClockedIn ? 'Clocked in at ${_formatTime(todayRecord.clockIn)}' : 'Clocked out at ${_formatTime(todayRecord.clockOut)}');

    final history = [...state.attendance]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

    // Month stats
    final now = DateTime.now();
    final monthRecs = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthRecs.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final lateDays = monthRecs.where((a) => a.status == 'LATE').length;
    final absentDays = monthRecs.where((a) => a.status == 'ABSENT').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendance Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('Clock in when entering the salon and clock out at end of shift.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),

              // Clock in/out card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isClockedIn
                        ? [const Color(0xFF065F46), const Color(0xFF047857)]
                        : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isClockedIn ? const Color(0xFF065F46) : AppTheme.primaryBlue).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    Text(
                      isClockedIn ? '● SHIFT ACTIVE' : '○ NOT CLOCKED IN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isClockedIn ? const Color(0xFF6EE7B7) : Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(statusLine, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () => _toggleClock(context, ref, isClockedIn),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIconsRegular.fingerprint,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isClockedIn ? 'Clock Out' : 'Clock In',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Month summary chips
              Row(
                children: [
                  _buildAttendChip('Present', '$presentDays days', AppTheme.accentGreen, AppTheme.accentGreenBg),
                  const SizedBox(width: 10),
                  _buildAttendChip('Late', '$lateDays days', AppTheme.accentAmber, AppTheme.accentAmberBg),
                  const SizedBox(width: 10),
                  _buildAttendChip('Absent', '$absentDays days', AppTheme.accentRed, AppTheme.accentRedBg),
                ],
              ),

              const SizedBox(height: 16),

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
                    const Text('Attendance History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.slateDark)),
                    const SizedBox(height: 14),
                    if (history.isEmpty)
                      const Text('No attendance records yet.', style: TextStyle(color: AppTheme.slateLight, fontSize: 12))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length > 20 ? 20 : history.length,
                        separatorBuilder: (context, idx) => const Divider(color: Color(0xFFF1F5F9), height: 16),
                        itemBuilder: (context, idx) {
                          final rec = history[idx];
                          Color statusColor = AppTheme.accentGreen;
                          Color statusBg = AppTheme.accentGreenBg;
                          if (rec.status == 'LATE') { statusColor = AppTheme.accentAmber; statusBg = AppTheme.accentAmberBg; }
                          if (rec.status == 'ABSENT') { statusColor = AppTheme.accentRed; statusBg = AppTheme.accentRedBg; }
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_formatDate(rec.date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    if (rec.clockIn != null)
                                      Text(
                                        'In: ${_formatTime(rec.clockIn)}${rec.clockOut != null ? '  •  Out: ${_formatTime(rec.clockOut)}' : ''}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.slateLight),
                                      ),
                                  ],
                                ),
                              ),
                              _statusBadge(rec.status, statusBg, statusColor),
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

  Widget _buildAttendChip(String label, String value, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: fg)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ─── Customers tab ───────────────────────────────────────────────────────────

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
                  const Text('Client Roster', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Search clients and view their visit history.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or phone...',
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
                              final lastVisit = c.lastVisitAt == null ? 'Never' : _formatDate(c.lastVisitAt);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.borderSubtle),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                  subtitle: Text('${c.phone} · Last visit: $lastVisit', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                                  trailing: Text('₹${c.totalSpent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.slateDark)),
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

// ─── Billing tab ─────────────────────────────────────────────────────────────

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
  double _manualDiscount = 0;
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
    final selectedCustomer = _selectedCustomerId == null ? null : _firstOrNull(state.customers.where((c) => c.id == _selectedCustomerId));

    double subtotal = 0;
    final selectedServices = <SalonService>[];
    for (final id in _selectedServiceIds) {
      final svc = state.services.where((s) => s.id == id);
      if (svc.isNotEmpty) { subtotal += svc.first.price; selectedServices.add(svc.first); }
    }
    final selectedProducts = <InventoryItem, int>{};
    for (final entry in _selectedProductQuantities.entries) {
      final prod = state.inventory.where((p) => p.id == entry.key);
      if (prod.isNotEmpty) {
        subtotal += prod.first.price * entry.value;
        selectedProducts[prod.first] = entry.value;
      }
    }
    final gstRate = state.settings?.gstRate ?? 18;
    final taxAmount = subtotal * (gstRate / 100);
    final discountedSubtotal = subtotal - _manualDiscount.clamp(0, subtotal);
    final total = discountedSubtotal + taxAmount;
    final hasItems = _selectedServiceIds.isNotEmpty || _selectedProductQuantities.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generate Bill', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('Select a customer, services and products to generate a bill.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),

              // Customer selector
              _SectionCard(
                title: 'Customer',
                icon: PhosphorIconsRegular.user,
                child: InkWell(
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: selectedCustomer != null ? AppTheme.primaryLight : const Color(0xFFE2E8F0),
                          child: Text(
                            selectedCustomer != null ? (selectedCustomer.name.isNotEmpty ? selectedCustomer.name[0] : '?') : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: selectedCustomer != null ? AppTheme.primaryBlue : AppTheme.slateLight,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedCustomer?.name ?? 'Choose client...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selectedCustomer != null ? AppTheme.slateDark : AppTheme.slateLight,
                            ),
                          ),
                        ),
                        const Icon(PhosphorIconsRegular.caretDown, size: 16, color: AppTheme.slateLight),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Services
              _SectionCard(
                title: 'Services',
                icon: PhosphorIconsRegular.scissors,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.services.isEmpty)
                      const Text('No services in catalog.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight))
                    else ...[
                      if (state.services.length > 5) ...[
                        TextField(
                          controller: _serviceSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search services...',
                            prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Builder(builder: (context) {
                        final query = _serviceSearchController.text.toLowerCase().trim();
                        final filtered = query.isEmpty ? state.services : state.services.where((s) => s.name.toLowerCase().contains(query)).toList();
                        if (filtered.isEmpty) return const Text('No services match.', style: TextStyle(fontSize: 12, color: AppTheme.slateLight));
                        return Column(
                          children: filtered.map((s) {
                            final isSel = _selectedServiceIds.contains(s.id);
                            return InkWell(
                              onTap: () => setState(() {
                                if (isSel) _selectedServiceIds.remove(s.id);
                                else _selectedServiceIds.add(s.id);
                              }),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.primaryLight : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? AppTheme.primaryBlue.withValues(alpha: 0.4) : AppTheme.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isSel ? AppTheme.primaryBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSel ? AppTheme.primaryBlue : AppTheme.borderStrong,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSel ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(s.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSel ? AppTheme.primaryBlue : AppTheme.slateDark)),
                                    ),
                                    Text('₹${s.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSel ? AppTheme.primaryBlue : AppTheme.slateMedium)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Products
              Builder(builder: (context) {
                final sellable = state.inventory.where((p) => p.stockCount > 0).toList();
                if (sellable.isEmpty) return const SizedBox.shrink();
                return _SectionCard(
                  title: 'Products & Retail',
                  icon: PhosphorIconsRegular.shoppingBag,
                  child: Column(
                    children: [
                      if (sellable.length > 5) ...[
                        TextField(
                          controller: _productSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(hintText: 'Search products...', prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18), isDense: true),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ...sellable.where((p) {
                        final query = _productSearchController.text.toLowerCase().trim();
                        return query.isEmpty || p.name.toLowerCase().contains(query);
                      }).map((prod) {
                        final qty = _selectedProductQuantities[prod.id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text('₹${prod.price.toStringAsFixed(0)} · ${prod.stockCount} in stock', style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
                                  ],
                                ),
                              ),
                              if (qty == 0)
                                OutlinedButton(
                                  onPressed: () => setState(() => _selectedProductQuantities[prod.id] = 1),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    side: const BorderSide(color: AppTheme.primaryBlue),
                                  ),
                                  child: const Text('Add', style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _qtyButton(PhosphorIconsRegular.minus, () => setState(() {
                                      if (qty <= 1) _selectedProductQuantities.remove(prod.id);
                                      else _selectedProductQuantities[prod.id] = qty - 1;
                                    })),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    _qtyButton(PhosphorIconsRegular.plus, qty >= prod.stockCount ? null : () => setState(() => _selectedProductQuantities[prod.id] = qty + 1)),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              // Payment method
              _SectionCard(
                title: 'Payment Method',
                icon: PhosphorIconsRegular.creditCard,
                child: Row(
                  children: ['CASH', 'CARD', 'UPI'].map((method) {
                    final isSel = _paymentMethod == method;
                    final colors = {'CASH': AppTheme.accentAmber, 'CARD': AppTheme.primaryBlue, 'UPI': AppTheme.accentGreen};
                    final color = colors[method] ?? AppTheme.primaryBlue;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: InkWell(
                          onTap: () => setState(() => _paymentMethod = method),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel ? color.withValues(alpha: 0.1) : Colors.transparent,
                              border: Border.all(color: isSel ? color : AppTheme.borderStrong, width: isSel ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(method, style: TextStyle(fontWeight: FontWeight.w700, color: isSel ? color : AppTheme.slateMedium, fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Summary
              if (hasItems)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line items
                      for (final svc in selectedServices) ...[
                        _buildLineItem(svc.name, svc.price),
                        const Divider(color: Color(0xFFF1F5F9), height: 12),
                      ],
                      for (final entry in selectedProducts.entries) ...[
                        _buildLineItem('${entry.key.name} ×${entry.value}', entry.key.price * entry.value),
                        const Divider(color: Color(0xFFF1F5F9), height: 12),
                      ],
                      const SizedBox(height: 4),
                      // Discount row
                      Row(
                        children: [
                          const Expanded(child: Text('Discount (Rs.)', style: TextStyle(fontSize: 13, color: AppTheme.slateMedium))),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), hintText: '0'),
                              onChanged: (v) => setState(() => _manualDiscount = double.tryParse(v) ?? 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GST', style: TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                          Text('₹${taxAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppTheme.borderSubtle),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Adjusted Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.slateDark)),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppTheme.primaryBlue),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_selectedCustomerId == null || !hasItems || _submitting) ? null : () => _submit(context, state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Complete & Generate Bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineItem(String name, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium))),
          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFF1F5F9) : AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: onTap == null ? AppTheme.slateLight : AppTheme.primaryBlue),
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
        builder: (ctx) => AppDialog(
          icon: PhosphorIconsRegular.checkCircle,
          iconColor: AppTheme.accentGreen,
          iconBackground: AppTheme.accentGreenBg,
          title: 'Bill Generated',
          subtitle: bill.invoiceNumber,
          child: Text(
            'Total: ₹${bill.finalAmount.toStringAsFixed(0)} via $_paymentMethod.',
            style: const TextStyle(fontSize: 14, color: AppTheme.slateMedium),
          ),
          actions: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedCustomerId = null;
                  _selectedServiceIds.clear();
                  _selectedProductQuantities.clear();
                  _manualDiscount = 0;
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
}

// ─── Earnings & Salary tab ───────────────────────────────────────────────────

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
              const Text('Earnings & Salary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('Live payout estimate for the current month.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
              const SizedBox(height: 20),

              // Hero earning card
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Earned (Est.)', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${estimatedNet.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kMonthAbbrevs[now.month - 1]} ${now.year} · Net payout estimate',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Stat chips row
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    left: BorderSide(color: AppTheme.borderSubtle),
                    right: BorderSide(color: AppTheme.borderSubtle),
                    bottom: BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _buildSalaryRow('Base Monthly Retainer', '₹${profile.baseSalary.toStringAsFixed(0)}', AppTheme.slateDark),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildSalaryRow('Pending Commission', '+ ₹${pendingCommission.toStringAsFixed(0)}', AppTheme.accentGreen),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildSalaryRow(
                      'Attendance Deductions${lateDays > 0 ? ' ($lateDays late)' : ''}',
                      '- ₹${deductions.toStringAsFixed(0)}',
                      deductions > 0 ? AppTheme.accentRed : AppTheme.slateMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Payout history
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
                    const SizedBox(height: 14),
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
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isPaid ? AppTheme.accentGreenBg : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPaid ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.clockCounterClockwise,
                                  size: 18,
                                  color: isPaid ? AppTheme.accentGreen : AppTheme.slateLight,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_kMonthAbbrevs[rec.month - 1]} ${rec.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                    _statusBadge(rec.status, isPaid ? AppTheme.accentGreenBg : const Color(0xFFF1F5F9), isPaid ? AppTheme.accentGreen : AppTheme.slateLight),
                                  ],
                                ),
                              ),
                              Text('₹${rec.totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                            ],
                          );
                        },
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

  Widget _buildSalaryRow(String title, String val, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }
}

// ─── Sales Target tab ────────────────────────────────────────────────────────

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
              const Text('Sales Targets', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(SalesTarget target) {
    Color statusColor = AppTheme.primaryBlue;
    Color statusBg = AppTheme.primaryLight;
    if (target.status == 'ACHIEVED') { statusColor = AppTheme.accentGreen; statusBg = AppTheme.accentGreenBg; }
    if (target.status == 'FAILED') { statusColor = AppTheme.accentRed; statusBg = AppTheme.accentRedBg; }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(_targetTypeLabel(target.type), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              _statusBadge(target.status, statusBg, statusColor),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_formatDate(target.startDate)} — ${_formatDate(target.endDate)}', style: const TextStyle(color: AppTheme.slateLight, fontSize: 11)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Achieved', style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    target.progressValue.toStringAsFixed(0),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -0.5),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Target', style: TextStyle(fontSize: 11, color: AppTheme.slateLight, fontWeight: FontWeight.w600)),
                  Text(target.targetValue.toStringAsFixed(0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(target.progressFraction * 100).toStringAsFixed(0)}% Completed',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.slateLight),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile / Account & Preferences tab ─────────────────────────────────────

class _EmployeeProfileTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final AppData state;
  final ValueChanged<int> onTabSelected;

  const _EmployeeProfileTab({required this.profile, required this.state, required this.onTabSelected});

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
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.lockKey,
          title: 'Change Password',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassController,
                obscureText: true,
                decoration: appDialogFieldDecoration(label: 'Current Password', hint: 'Enter current password', icon: PhosphorIconsRegular.lockKey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: appDialogFieldDecoration(label: 'New Password', hint: 'min 8 characters', icon: PhosphorIconsRegular.lockSimple),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: appDialogFieldDecoration(label: 'Confirm New Password', hint: 'Re-enter new password', icon: PhosphorIconsRegular.lockSimple),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Save Password',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              if (newPassController.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 8 characters long.'), backgroundColor: AppTheme.accentRed));
                return;
              }
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match.'), backgroundColor: AppTheme.accentRed));
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppTheme.accentGreen));
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
    final profile = widget.profile;
    final state = widget.state;
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut == null;

    final now = DateTime.now();
    final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final presentDays = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
    final attendancePct = monthAttendance.isEmpty ? 0.0 : (presentDays / monthAttendance.length) * 100;

    final activeTargets = state.salesTargets.where((t) => t.employeeId == profile.id && t.status == 'ACTIVE');
    final target = activeTargets.isEmpty ? null : activeTargets.first;

    final initials = profile.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Account & Preferences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
              const SizedBox(height: 18),

              // Profile card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Center(
                            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isClockedIn ? AppTheme.accentGreen : AppTheme.textMuted,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.slateDark)),
                    const SizedBox(height: 4),
                    Text(profile.email, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _statusBadge(profile.roleTitle, AppTheme.primaryLight, AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        _statusBadge(
                          isClockedIn ? '● Active' : '○ Off Duty',
                          isClockedIn ? AppTheme.accentGreenBg : const Color(0xFFF1F5F9),
                          isClockedIn ? AppTheme.accentGreen : AppTheme.slateLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCol('Attendance', '${attendancePct.toStringAsFixed(0)}%', AppTheme.accentGreen),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatCol('Target', target == null ? '—' : '${(target.progressFraction * 100).toStringAsFixed(0)}%', AppTheme.primaryBlue),
                        Container(width: 1, height: 32, color: AppTheme.borderSubtle),
                        _buildStatCol('Commission', '${profile.serviceCommissionPct.toStringAsFixed(0)}%', AppTheme.slateDark),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Menu list
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.calendarBlank,
                      iconColor: AppTheme.primaryBlue,
                      iconBg: AppTheme.primaryLight,
                      title: 'Attendance Logs',
                      subtitle: 'View your shift history',
                      onTap: () => widget.onTabSelected(1),
                    ),
                    const Divider(height: 1, indent: 62, color: AppTheme.borderSubtle),
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.coins,
                      iconColor: AppTheme.accentGreen,
                      iconBg: AppTheme.accentGreenBg,
                      title: 'Commission Review',
                      subtitle: '₹${state.commissions.where((c) => c.employeeId == profile.id && c.status == 'PENDING').fold<double>(0, (s, c) => s + c.amount).toStringAsFixed(0)} pending',
                      onTap: () => widget.onTabSelected(4),
                    ),
                    const Divider(height: 1, indent: 62, color: AppTheme.borderSubtle),
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.wallet,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF5F3FF),
                      title: 'Earnings & Billing',
                      subtitle: 'Salary breakdown & payout history',
                      onTap: () => widget.onTabSelected(4),
                    ),
                    const Divider(height: 1, indent: 62, color: AppTheme.borderSubtle),
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.chartLineUp,
                      iconColor: AppTheme.accentAmber,
                      iconBg: AppTheme.accentAmberBg,
                      title: 'Sales Target',
                      subtitle: target == null ? 'No active target' : '${(target.progressFraction * 100).toStringAsFixed(0)}% completed',
                      onTap: () => widget.onTabSelected(5),
                    ),
                    const Divider(height: 1, indent: 62, color: AppTheme.borderSubtle),
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.userCircle,
                      iconColor: AppTheme.slateMedium,
                      iconBg: const Color(0xFFF1F5F9),
                      title: 'Account Profile',
                      subtitle: '${profile.email} · ${profile.phone}',
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    const Divider(height: 1, indent: 62, color: AppTheme.borderSubtle),
                    _buildMenuTile(
                      icon: PhosphorIconsRegular.tag,
                      iconColor: AppTheme.accentRed,
                      iconBg: AppTheme.accentRedBg,
                      title: 'Discount Requests',
                      subtitle: '${state.discountRequests.where((r) => r.status == 'PENDING').length} pending approvals',
                      onTap: () => widget.onTabSelected(7),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Logout
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AppDialog(
                        icon: PhosphorIconsRegular.signOut,
                        iconColor: AppTheme.accentRed,
                        iconBackground: AppTheme.accentRedBg,
                        title: 'Confirm Logout',
                        child: const Text(
                          'Are you sure you want to end your current session?',
                          style: TextStyle(fontSize: 14, color: AppTheme.slateMedium),
                        ),
                        actions: AppDialogActions(
                          submitLabel: 'Log Out',
                          submitColor: AppTheme.accentRed,
                          onCancel: () => Navigator.pop(ctx),
                          onSubmit: () {
                            Navigator.pop(ctx);
                            ref.read(authControllerProvider.notifier).logout();
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 18, color: AppTheme.accentRed),
                  label: const Text('Log Out of Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppTheme.slateLight),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
      ],
    );
  }
}

// ─── Discount Requests tab ───────────────────────────────────────────────────

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
        builder: (ctx, setDialogState) => AppDialog(
          icon: PhosphorIconsRegular.tag,
          title: 'Request Discount',
          subtitle: 'Sent to your manager for approval.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String?>(
                value: selectedBillId,
                decoration: appDialogFieldDecoration(label: 'Linked Bill (optional)', icon: PhosphorIconsRegular.receipt),
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
                        '${b.invoiceNumber} - ${b.customerName ?? "Customer"} (₹${b.finalAmount.toStringAsFixed(0)})',
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
                decoration: appDialogFieldDecoration(label: 'Requested Discount (Rs.) *', hint: 'e.g. 200', icon: PhosphorIconsRegular.percent),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: overrideController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: appDialogFieldDecoration(label: 'Override Price (Rs., optional)', hint: 'Leave blank unless setting a fixed final price', icon: PhosphorIconsRegular.currencyInr),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: appDialogFieldDecoration(label: 'Reason *', hint: 'Why does this customer need extra discount?', icon: PhosphorIconsRegular.chatText),
              ),
            ],
          ),
          actions: AppDialogActions(
            submitLabel: 'Send Request',
            submitting: submitting,
            onCancel: () => Navigator.pop(ctx),
            onSubmit: () async {
              final discount = double.tryParse(discountController.text.trim());
              if (discount == null || discount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid discount amount.'), backgroundColor: AppTheme.accentRed));
                return;
              }
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A reason is required.'), backgroundColor: AppTheme.accentRed));
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to your manager.'), backgroundColor: AppTheme.accentGreen));
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

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED': return AppTheme.accentGreen;
      case 'REJECTED': return AppTheme.accentRed;
      default: return AppTheme.accentAmber;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'APPROVED': return AppTheme.accentGreenBg;
      case 'REJECTED': return AppTheme.accentRedBg;
      default: return AppTheme.accentAmberBg;
    }
  }

  Widget _buildRequestCard(BuildContext context, DiscountRequest req) {
    final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
    final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;
    final statusColor = _statusColor(req.status);
    final statusBackground = _statusBg(req.status);

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
                  matchedBill != null ? '${matchedBill.customerName ?? "Customer"} · ${matchedBill.invoiceNumber}' : 'General request',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusBadge(req.status, statusBackground, statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Requested ₹${req.requestedDiscount.toStringAsFixed(0)} off${req.overridePrice != null ? ' · override ₹${req.overridePrice!.toStringAsFixed(0)}' : ''}',
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
                const Text('Discount Requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('Ask your manager to approve a discount beyond what you can give.', style: TextStyle(color: AppTheme.slateLight, fontSize: 13)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showNewRequestDialog(context, ref),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                    label: const Text('New Request', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared section card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              Icon(icon, size: 16, color: AppTheme.slateMedium),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.slateDark)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
