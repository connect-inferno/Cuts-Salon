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
import '../../widgets/liquid_nav_bar.dart';

const double _kMobileBreakpoint = 800;

const List<String> _kMonthAbbrevs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> _kWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
    final appData = ref.watch(appDataProvider).valueOrNull;
    final salonName = appData?.settings?.salonName ??
        ref.watch(authControllerProvider).salonName ??
        'Cuts Salon';
    final pendingDiscountCount = appData?.discountRequests.where((r) => r.status == 'PENDING' && r.requestedBy == empProfile.id).length ?? 0;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile ? null : const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Center(
                    child: Icon(
                      PhosphorIconsRegular.storefront,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              empProfile.name,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Drawer Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: _tabNames.length,
              itemBuilder: (context, index) {
                final isSelected = _activeTabIndex == index;
                final icon = _tabIcons[index];
                final name = _tabNames[index];
                final isSalary = index == 4;
                final isDiscount = index == 7;

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
                        color: isSelected
                            ? const Color(0xFFEEF2FF)
                            : (isSalary ? const Color(0xFFF8FAFC) : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: const Color(0xFFC7D2FE))
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : (isSalary ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                            size: 19,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF334155),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSalary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          if (isDiscount && pendingDiscountCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingDiscountCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
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

          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(PhosphorIconsRegular.signOut, size: 16, color: Color(0xFFEF4444)),
              label: const Text(
                'Log Out',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                side: const BorderSide(color: Color(0xFFFEE2E2)),
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _switchToTab(int index) {
    setState(() {
      _activeTabIndex = index;
    });
  }

  Widget _buildScaffold(BuildContext context, EmployeeProfile empProfile, AppData state) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final salonName = ref.watch(appDataProvider).valueOrNull?.settings?.salonName ??
        ref.watch(authControllerProvider).salonName ??
        'Salon';

    final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING' && r.requestedBy == empProfile.id).length;

    // 0: Dashboard (tab 0), 1: Billing (tab 3), 2: Center (+ New), 3: Customers (tab 2), 4: More (tabs 1, 4, 5, 6, 7)
    int navIndex = 0;
    if (_activeTabIndex == 0) {
      navIndex = 0;
    } else if (_activeTabIndex == 3) {
      navIndex = 1;
    } else if (_activeTabIndex == 2) {
      navIndex = 3;
    } else {
      navIndex = 4;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: isMobile,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.storefront,
                    color: Color(0xFF4F46E5),
                    size: 18,
                  ),
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  Text(
                    salonName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Badge(
                    smallSize: 8,
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(PhosphorIconsRegular.bell, color: Color(0xFF475467), size: 20),
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTabIndex = 6),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF4F46E5),
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
          ? _buildModernFloatingNavBar(context, navIndex, pendingDiscountCount)
          : null,
      body: SafeArea(
        bottom: !isMobile,
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

  // Shared with the owner dashboard - see widgets/liquid_nav_bar.dart for
  // the glass/flow/spring behaviour. This file used to carry its own
  // byte-for-byte copy of the bar, so the two drifted apart on every touch.
  Widget _buildModernFloatingNavBar(BuildContext context, int navIndex, int pendingDiscountCount) {
    return LiquidNavBar(
      selectedIndex: navIndex,
      onCenterTap: () => _showQuickCreateSheet(context),
      centerIcon: PhosphorIconsBold.plus,
      items: [
        LiquidNavItem(
          icon: PhosphorIconsRegular.squaresFour,
          activeIcon: PhosphorIconsFill.squaresFour,
          label: 'Dashboard',
          onTap: () => _switchToTab(0),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.receipt,
          activeIcon: PhosphorIconsFill.receipt,
          label: 'Billing',
          onTap: () => _switchToTab(3),
        ),
        null, // the protruding "+" button is drawn over this slot
        LiquidNavItem(
          icon: PhosphorIconsRegular.users,
          activeIcon: PhosphorIconsFill.users,
          label: 'Customers',
          onTap: () => _switchToTab(2),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.dotsThree,
          activeIcon: PhosphorIconsFill.dotsThree,
          label: 'More',
          badgeCount: pendingDiscountCount,
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          onLongPress: () => _showMoreMenu(context),
        ),
      ],
    );
  }

  void _showQuickCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Without this the sheet is capped at 9/16 of the screen and the four
      // tiles overflow it; the ConstrainedBox then stops it growing past the
      // screen on short viewports, and the tiles scroll inside instead.
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
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
                const SizedBox(height: 16),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _buildQuickActionTile(
                        icon: PhosphorIconsBold.shoppingCart,
                        iconColor: const Color(0xFF4F46E5),
                        bgColor: const Color(0xFFEEF2FF),
                        title: 'Start New Bill',
                        subtitle: 'Create a new invoice and checkout services',
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchToTab(3);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActionTile(
                        icon: PhosphorIconsBold.calendarCheck,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        title: 'Attendance & Clock-In',
                        subtitle: 'Clock in, clock out or check shift logs',
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchToTab(1);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActionTile(
                        icon: PhosphorIconsBold.users,
                        iconColor: const Color(0xFF0D9488),
                        bgColor: const Color(0xFFE6FFFA),
                        title: 'Customer Roster',
                        subtitle: 'Look up client history and client profiles',
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchToTab(2);
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActionTile(
                        icon: PhosphorIconsBold.tag,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        title: 'Request Discount',
                        subtitle: 'Submit a discount request for owner approval',
                        onTap: () {
                          Navigator.pop(ctx);
                          _switchToTab(7);
                        },
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
      },
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight, size: 16, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'More Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Quick access to all employee tools & drawer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.sidebarSimple, color: Color(0xFF4F46E5)),
                      tooltip: 'Open Full Drawer',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.wallet,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  title: 'Earnings & Salary',
                  subtitle: 'Live estimated payout, commissions & slips',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(4);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.calendarBlank,
                  iconColor: const Color(0xFF6366F1),
                  bgColor: const Color(0xFFEEF2FF),
                  title: 'Attendance Logs',
                  subtitle: 'Review clock-in logs and work shifts',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(1);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.users,
                  iconColor: const Color(0xFF0D9488),
                  bgColor: const Color(0xFFE6FFFA),
                  title: 'Customer Roster',
                  subtitle: 'View salon client history and profiles',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(2);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.receipt,
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  title: 'Quick Billing',
                  subtitle: 'Fast POS terminal invoice generator',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(3);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.chartLineUp,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  title: 'Sales Targets',
                  subtitle: 'Monthly performance and target tracking',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(5);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.tag,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF5F3FF),
                  title: 'Discount Requests',
                  subtitle: 'Track status of discounts submitted to owner',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(7);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.userCircle,
                  iconColor: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  title: 'Personal Profile',
                  subtitle: 'Employee profile, specialization and settings',
                  onTap: () {
                    Navigator.pop(ctx);
                    _switchToTab(6);
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickActionTile(
                  icon: PhosphorIconsBold.list,
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  title: 'Open Menu Drawer',
                  subtitle: 'View the complete navigation drawer',
                  onTap: () {
                    Navigator.pop(ctx);
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(authControllerProvider.notifier).logout();
                  },
                  icon: const Icon(PhosphorIconsBold.signOut, size: 18, color: Color(0xFFEF4444)),
                  label: const Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: Color(0xFFFEE2E2)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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

    String shiftDuration = '--';
    if (isClockedIn && todayRecord.clockIn != null) {
      final diff = now.difference(todayRecord.clockIn!);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      shiftDuration = '${h}h ${m}m';
    }

    const monthFullNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateFormatted = '${_kWeekdays[now.weekday - 1]}, ${now.day} ${monthFullNames[now.month - 1]} ${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // 1. Designation Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  profile.roleTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Greeting & Date
          Text(
            'Good ${_greeting(now.hour)}, $firstName',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            dateFormatted,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Three Stat Cards (Shift Hours, Clients, Earned Today)
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: PhosphorIconsRegular.clock,
                  iconBg: const Color(0xFFF1F5F9),
                  iconColor: const Color(0xFF475467),
                  label: 'Shift Hours',
                  valueWidget: Text(
                    todayRecord?.clockIn == null
                        ? '--'
                        : '${_formatTime(todayRecord!.clockIn)} – ${todayRecord.clockOut == null ? 'now' : _formatTime(todayRecord.clockOut)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: PhosphorIconsRegular.users,
                  iconBg: const Color(0xFFEEF2FF),
                  iconColor: const Color(0xFF4F46E5),
                  label: 'Clients',
                  valueWidget: RichText(
                    text: TextSpan(
                      text: '$todayCustomers ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      children: const [
                        TextSpan(
                          text: 'done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: PhosphorIconsRegular.money,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF10B981),
                  label: 'Earned Today',
                  valueWidget: Text(
                    '₹${todayRevenue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Shift Card (Clocked In / Clocked Out)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isClockedIn ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isClockedIn ? 'Clocked In' : 'Clocked Out',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              isClockedIn ? 'ACTIVE SHIFT' : 'INACTIVE SHIFT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isClockedIn ? const Color(0xFF0D9488) : const Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.clock, size: 13, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 5),
                          Text(
                            shiftDuration,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleClock(context, ref, isClockedIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Icon(
                      isClockedIn ? PhosphorIconsRegular.signOut : PhosphorIconsRegular.fingerprint,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      isClockedIn ? 'Clock Out' : 'Clock In',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Fast POS New Billing / Checkout Hero Card
          InkWell(
            onTap: () => onTabSelected(3),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FAST POS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(PhosphorIconsRegular.receipt, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Billing /\nCheckout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Quick-create invoice & collect client payment',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsBold.arrowRight,
                            color: Color(0xFF4F46E5),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 6. Recent Bills Handled
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Recent Bills Handled',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onTabSelected(3),
                      child: Text(
                        'See all (${myBills.length})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (recentBills.isNotEmpty)
                  for (int i = 0; i < recentBills.length; i++) ...[
                    if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildBillItem(recentBills[i], profile.id),
                  ]
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No bills handled yet.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required Widget valueWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          valueWidget,
        ],
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
          radius: 17,
          backgroundColor: const Color(0xFFEEF2FF),
          child: Text(
            initials,
            style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(
                serviceNames,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${myTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$time • Paid',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                ),
              ],
            ),
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
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final asyncData = ref.watch(appDataProvider);
        return asyncData.when(
          loading: () => const AppLoadingView(),
          error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
          data: (state) => _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppData state) {
    final q = _searchQuery.toLowerCase().trim();
    final vipCount = state.customers.where((c) => c.isVip).length;
    final returningCount = state.customers.where((c) => c.visitCount > 1).length;

    final filtered = state.customers.where((c) {
      final matches = q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q);
      if (!matches) return false;
      if (_filter == 'VIP') return c.isVip;
      if (_filter == 'Returning') return c.visitCount > 1;
      return true;
    }).toList()
      ..sort((a, b) => (b.lastVisitAt ?? DateTime(0)).compareTo(a.lastVisitAt ?? DateTime(0)));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Roster',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          const Text(
            'Search clients and view their visit history.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Summary tiles
          Row(
            children: [
              _summaryTile(
                icon: PhosphorIconsRegular.usersThree,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: const Color(0xFF4F46E5),
                label: 'Total',
                value: '${state.customers.length}',
              ),
              const SizedBox(width: 8),
              _summaryTile(
                icon: PhosphorIconsFill.star,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                label: 'VIP',
                value: '$vipCount',
              ),
              const SizedBox(width: 8),
              _summaryTile(
                icon: PhosphorIconsRegular.arrowsClockwise,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF10B981),
                label: 'Returning',
                value: '$returningCount',
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', state.customers.length),
                const SizedBox(width: 8),
                _filterChip('VIP', vipCount),
                const SizedBox(width: 8),
                _filterChip('Returning', returningCount),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(PhosphorIconsRegular.usersThree, size: 34, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 10),
                  Text(
                    'No clients found.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Try a different name, phone or filter.',
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
                  for (int i = 0; i < filtered.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    _clientRow(filtered[i], i),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
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

  Widget _clientRow(Customer c, int idx) {
    const avatarBgs = [Color(0xFFEEF2FF), Color(0xFFFEF3C7), Color(0xFFF5F3FF), Color(0xFFCCFBF1), Color(0xFFFCE7F3)];
    const avatarFgs = [Color(0xFF4F46E5), Color(0xFFD97706), Color(0xFF7C3AED), Color(0xFF0D9488), Color(0xFFDB2777)];
    final bg = avatarBgs[idx % avatarBgs.length];
    final fg = avatarFgs[idx % avatarFgs.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: fg),
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
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.isVip) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(PhosphorIconsRegular.phone, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      c.phone,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        c.lastVisitAt == null ? 'Never' : _formatDate(c.lastVisitAt),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${c.totalSpent.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                '${c.visitCount} visit${c.visitCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
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
  // Selections start empty and only ever hold ids the employee actually
  // tapped in the live catalog below. They used to be seeded with demo ids
  // ('s1', 'p1', ...) from the design mockup, which no real salon has - and
  // since an id can only be removed by tapping its own row, those ghost ids
  // were unremovable and made every createBill() call fail with
  // 'Service not found'.
  final Set<String> _selectedServiceIds = {};
  final Map<String, int> _selectedProductQuantities = {};
  String _paymentMethod = 'UPI';
  // Only used when _paymentMethod == 'PENDING': what the client hands over
  // now, with the balance becoming a due against them. Blank = paying it all
  // later.
  final _partPaymentController = TextEditingController();
  String _partPaymentMethod = 'CASH';
  bool _submitting = false;

  @override
  void dispose() {
    _partPaymentController.dispose();
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
    final allServices = state.services
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'subtitle': s.categoryName ?? 'Service',
              'price': s.price,
            })
        .toList();

    final allProducts = state.inventory
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'price': p.price,
              'stock': '${p.stockCount} in stock',
              'stockCount': p.stockCount,
              'isLow': p.stockCount <= 5,
            })
        .toList();

    Customer? selectedCustomer;
    if (_selectedCustomerId != null) {
      final matches = state.customers.where((c) => c.id == _selectedCustomerId);
      if (matches.isNotEmpty) selectedCustomer = matches.first;
    }

    // Calculations. These mirror the transaction in SalonFirestore.createBill
    // (subTotal -> taxable -> taxAmount -> finalAmount) exactly, so the total
    // quoted to the customer here is the total that actually gets written.
    // This screen used to invent a 10% 'VIP' discount, a flat Rs.50 promo and
    // a hardcoded 18% GST that the write path knew nothing about, so the
    // amount collected never matched the stored bill.
    double serviceTotal = 0;
    int serviceCount = 0;
    for (final s in allServices) {
      if (_selectedServiceIds.contains(s['id'])) {
        serviceTotal += (s['price'] as double);
        serviceCount++;
      }
    }

    double productTotal = 0;
    int productItemCount = 0;
    for (final p in allProducts) {
      final qty = _selectedProductQuantities[p['id']] ?? 0;
      if (qty > 0) {
        productTotal += (p['price'] as double) * qty;
        productItemCount += qty;
      }
    }

    final subtotal = serviceTotal + productTotal;
    final gstRate = state.settings?.effectiveGstRate ?? 0;
    final gstAmount = subtotal * (gstRate / 100);
    final total = subtotal + gstAmount;
    final itemCount = serviceCount + productItemCount;
    final canSubmit = selectedCustomer != null && itemCount > 0;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 1. Header (NO BACK BUTTON - per requirement)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate Client Bill',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select a customer, then add services or products.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  // The invoice number is generated by the createBill
                  // transaction (INV-xxxxxxxx), so there is nothing real to
                  // show here until the bill exists.
                ],
              ),
              const SizedBox(height: 16),

              // 2. Customer Card
              InkWell(
                onTap: () async {
                  if (state.customers.isNotEmpty) {
                    final c = await showSearchablePicker<Customer>(
                      context: context,
                      title: 'Select Customer',
                      items: state.customers,
                      labelOf: (item) => item.name,
                      subtitleOf: (item) => item.phone,
                    );
                    if (c != null) setState(() => _selectedCustomerId = c.id);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Center(
                          child: Icon(PhosphorIconsRegular.user, color: Color(0xFF4F46E5), size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'CUSTOMER',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (selectedCustomer?.isVip == true) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'VIP',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              selectedCustomer?.name ?? 'Tap to select a customer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: selectedCustomer == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            if (selectedCustomer != null) ...[
                              const SizedBox(height: 1),
                              Text(
                                selectedCustomer.phone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(PhosphorIconsRegular.caretRight, size: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Services Section
              Row(
                children: [
                  const Text(
                    'Services',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$serviceCount Selected',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),

              // Service List Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: allServices.isEmpty
                    ? const _BillingCatalogEmpty(
                        message: 'No services in the catalog yet.',
                        hint: 'Your owner can add them from the Services tab.',
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < allServices.length; i++) ...[
                            if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 18),
                            _buildServiceItem(allServices[i]),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // 4. Products & Retail Section
              Row(
                children: [
                  const Text(
                    'Products & Retail',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$productItemCount Selected',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),

              // Product List Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: allProducts.isEmpty
                    ? const _BillingCatalogEmpty(
                        message: 'No products in inventory yet.',
                        hint: 'Your owner can add stock from the Inventory tab.',
                      )
                    : Column(
                        children: [
                          for (int i = 0; i < allProducts.length; i++) ...[
                            if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 18),
                            _buildProductItem(allProducts[i]),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // 5. Payment Method Section
              Row(
                children: const [
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 10),

              // Payment options row (Cash, UPI/QR, Card, Split/Later)
              Row(
                children: [
                  _buildPaymentCard('CASH', 'Cash', PhosphorIconsRegular.money),
                  const SizedBox(width: 8),
                  _buildPaymentCard('UPI', 'UPI / QR', PhosphorIconsRegular.qrCode),
                  const SizedBox(width: 8),
                  _buildPaymentCard('CARD', 'Card', PhosphorIconsRegular.creditCard),
                  const SizedBox(width: 8),
                  _buildPaymentCard('PENDING', 'Pay Later', PhosphorIconsRegular.clockCountdown),
                ],
              ),

              // 'SPLIT' used to sit in that last slot and did nothing at all
              // - it was stored as the bill's payment method and no balance
              // was ever tracked against it. It's now PENDING, and this is
              // where the amount actually collected gets captured.
              if (_paymentMethod == 'PENDING') ...[
                const SizedBox(height: 10),
                _buildPartPaymentBox(total),
              ],
              const SizedBox(height: 18),

              // 6. Bill Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Breakdown',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBreakdownRow('Services ($serviceCount ${serviceCount == 1 ? 'item' : 'items'})', '₹${serviceTotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    _buildBreakdownRow('Retail Products ($productItemCount ${productItemCount == 1 ? 'item' : 'items'})', '₹${productTotal.toStringAsFixed(0)}'),
                    const SizedBox(height: 6),
                    _buildBreakdownRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}', isBold: true),
                    // GST is off until the owner sets a rate in Settings, so
                    // the row only appears when there is tax to charge.
                    if (gstRate > 0) ...[
                      const SizedBox(height: 6),
                      _buildBreakdownRow('CGST + SGST (${gstRate.toStringAsFixed(0)}%)', '₹${gstAmount.toStringAsFixed(0)}'),
                    ],
                  ],
                ),
              ),

              // Padding for bottom bar + navbar
              const SizedBox(height: 220),
            ],
          ),
        ),

        // Sticky Bottom Total Bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 90, // Above floating navbar
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL AMOUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          gstRate > 0 ? 'Inclusive of GST' : 'No GST applied',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (_submitting || !canSubmit) ? null : () => _submit(context, state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(PhosphorIconsRegular.receipt, size: 18, color: Colors.white),
                    label: Text(
                      selectedCustomer == null
                          ? 'Select a customer to continue'
                          : (itemCount == 0 ? 'Add a service or product' : 'Complete & Generate Bill'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> s) {
    final id = s['id'] as String;
    final isSelected = _selectedServiceIds.contains(id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedServiceIds.remove(id);
          } else {
            _selectedServiceIds.add(id);
          }
        });
      },
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${(s['price'] as double).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final qty = _selectedProductQuantities[id] ?? 0;
    final isLow = p['isLow'] == true;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p['name'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '₹${(p['price'] as double).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLow ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p['stock'] as String,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isLow ? const Color(0xFFD97706) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (qty > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (qty <= 1) {
                        _selectedProductQuantities.remove(id);
                      } else {
                        _selectedProductQuantities[id] = qty - 1;
                      }
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PhosphorIconsRegular.minus, size: 10, color: Color(0xFF4F46E5)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '$qty',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProductQuantities[id] = qty + 1;
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(PhosphorIconsBold.plus, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: () {
              setState(() {
                _selectedProductQuantities[id] = 1;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.plus, size: 11, color: Color(0xFF475467)),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475467),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Appears under the payment row once "Pay Later" is chosen: how much is
  /// being collected now, and what that leaves owing. Blank means nothing is
  /// collected today, which is the usual "settle next visit" case.
  Widget _buildPartPaymentBox(double total) {
    final entered = double.tryParse(_partPaymentController.text.trim()) ?? 0;
    final paidNow = entered.clamp(0, total).toDouble();
    final due = total - paidNow;
    final overTyped = entered > total;

    return Container(
      padding: const EdgeInsets.all(12),
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
              const Icon(PhosphorIconsRegular.clockCountdown, size: 14, color: Color(0xFFB45309)),
              const SizedBox(width: 5),
              const Text(
                'Paying later',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
              const Spacer(),
              Text(
                '₹${due.toStringAsFixed(0)} will be owed',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
              hintText: 'Collecting now (blank for nothing)',
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              errorText: overTyped ? 'More than the bill total' : null,
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
                  'via',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                ),
                const SizedBox(width: 8),
                for (final m in ['CASH', 'UPI', 'CARD'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _partPaymentMethod = m),
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

  Widget _buildPaymentCard(String method, String label, IconData icon) {
    final isSelected = _paymentMethod == method;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String title, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, AppData state) async {
    final customerId = _selectedCustomerId;
    if (customerId == null) return;

    // Only ever send ids that are still in the loaded catalog - an item the
    // owner deleted while this screen was open would otherwise be rejected by
    // createBill() with a confusing 'Service not found'.
    final serviceIds = state.services.map((s) => s.id).toSet();
    final inventoryIds = state.inventory.map((i) => i.id).toSet();
    final items = [
      ..._selectedServiceIds
          .where(serviceIds.contains)
          .map((id) => BillItemInput(type: 'SERVICE', serviceId: id, employeeId: widget.profile.id, quantity: 1)),
      ..._selectedProductQuantities.entries
          .where((e) => e.value > 0 && inventoryIds.contains(e.key))
          .map((e) => BillItemInput(type: 'PRODUCT', inventoryItemId: e.key, employeeId: widget.profile.id, quantity: e.value)),
    ];
    if (items.isEmpty) return;

    setState(() => _submitting = true);
    try {
      // createBill re-resolves every price, commission and GST rate against
      // the loaded AppData snapshot, so the bill it returns - not the figure
      // this screen rendered - is the source of truth for what was charged.
      final isPending = _paymentMethod == 'PENDING';
      final typedNow = double.tryParse(_partPaymentController.text.trim()) ?? 0;
      final bill = await ref.read(appDataProvider.notifier).createBill(
            customerId: customerId,
            branchId: widget.profile.branchId,
            // A part-paid bill records the method the collected portion came
            // in on; only a wholly unpaid one stays PENDING.
            paymentMethod: isPending && typedNow > 0 ? _partPaymentMethod : _paymentMethod,
            items: items,
            amountPaidNow: isPending ? typedNow : null,
          );

      if (!mounted) return;
      setState(() {
        _selectedServiceIds.clear();
        _selectedProductQuantities.clear();
        _selectedCustomerId = null;
        _partPaymentController.clear();
      });

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AppDialog(
          icon: PhosphorIconsRegular.checkCircle,
          iconColor: AppTheme.accentGreen,
          iconBackground: AppTheme.accentGreenBg,
          title: 'Bill Completed',
          subtitle: 'Invoice ${bill.invoiceNumber} generated',
          child: Text(
            bill.amountDue > 0
                ? 'Total ₹${bill.finalAmount.toStringAsFixed(0)}. '
                    '${bill.amountPaid > 0 ? 'Collected ₹${bill.amountPaid.toStringAsFixed(0)}. ' : ''}'
                    '₹${bill.amountDue.toStringAsFixed(0)} left to collect from this client.'
                : 'Total amount ₹${bill.finalAmount.toStringAsFixed(0)} collected via ${bill.paymentMethod}.',
            style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium),
          ),
          actions: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
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

class _BillingCatalogEmpty extends StatelessWidget {
  final String message;
  final String hint;

  const _BillingCatalogEmpty({required this.message, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
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
    final split = state.pendingCommissionFor(profile.id);
    final pendingCommission = split.total;

    final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
    final lateDays = monthAttendance.where((a) => a.status == 'LATE').length;
    final penaltyRate = state.settings?.lateAttendancePenalty ?? 0;
    final deductions = lateDays * penaltyRate;
    final estimatedNet = profile.baseSalary + pendingCommission - deductions;

    final displayBase = profile.baseSalary;
    final displayPendingComm = pendingCommission;
    final displayNet = estimatedNet;

    // Same split the owner's Payroll Estimate card shows (AppData.
    // pendingCommissionFor), so the two screens can't report different
    // numbers for this employee's pay. It breaks down `pendingCommission`
    // above, so the parts add up to the headline figure.
    final serviceCommission = split.service;
    final productCommission = split.product;
    final serviceBillings = split.serviceBillings;
    final productBillings = split.productBillings;

    // Real payout history, newest first - the page previously showed three
    // hardcoded 2024 rows.
    final payouts = [...state.salaryRecords.where((r) => r.employeeId == profile.id)]
      ..sort((a, b) => (b.year * 100 + b.month).compareTo(a.year * 100 + a.month));

    final activeTarget = state.salesTargets
        .where((t) => t.employeeId == profile.id && t.status == 'ACTIVE')
        .fold<SalesTarget?>(null, (prev, t) => prev ?? t);

    const monthFullNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = monthFullNames[now.month - 1];
    final currentMonthShort = _kMonthAbbrevs[now.month - 1];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // 1. Header (Earnings & Salary + Month selector)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Earnings & Salary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$currentMonthName ${now.year} • Pay Period Active',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentMonthShort ${now.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(PhosphorIconsRegular.caretDown, size: 12, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Hero Net Payout (Estimated) Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'Net Payout (Estimated)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475467),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(PhosphorIconsRegular.info, size: 13, color: Color(0xFF94A3B8)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Calculating live',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
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
                      '₹${displayNet.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (activeTarget != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Paced for ₹${activeTarget.targetValue.toStringAsFixed(0)} target',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 14),

                // Base Retainer Row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(PhosphorIconsRegular.wallet, size: 16, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Base Monthly Retainer',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Text(
                      '₹${displayBase.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pending Commission Row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(PhosphorIconsRegular.trendUp, size: 16, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pending Commission',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          Text(
                            '${profile.serviceCommissionPct.toStringAsFixed(0)}% Service + ${profile.productCommissionPct.toStringAsFixed(0)}% Retail',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${displayPendingComm.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Two Metric Cards Row (Service Commission & Retail Commission)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(PhosphorIconsRegular.scissors, size: 14, color: Color(0xFF4F46E5)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${profile.serviceCommissionPct.toStringAsFixed(0)}% Svc',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Service Commission',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${serviceCommission.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From ₹${serviceBillings.toStringAsFixed(0)} billings',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(PhosphorIconsRegular.shoppingBag, size: 14, color: Color(0xFF10B981)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${profile.productCommissionPct.toStringAsFixed(0)}% Ret',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Retail Commission',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${productCommission.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From ₹${productBillings.toStringAsFixed(0)} sales',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Payout History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payout History',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Past finalized statements & tax slips',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Payout History Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: payouts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No payouts recorded yet.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < payouts.length && i < 6; i++) ...[
                        if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 18),
                        _buildPayoutRow(
                          '${monthFullNames[payouts[i].month - 1]}\n${payouts[i].year}',
                          payouts[i].status == 'PAID' ? 'Paid' : 'Draft - not yet paid',
                          '₹${payouts[i].totalPaid.toStringAsFixed(0)}',
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // 5. TDS & Direct Bank Settlement Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(PhosphorIconsRegular.shieldCheck, size: 18, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TDS & Direct Bank Settlement',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Payouts are credited directly to HDFC Bank (•••• 4920) on the 1st of every month after applicable tax deductions.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(String period, String subtitle, String amount) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Icon(PhosphorIconsRegular.receipt, size: 18, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PAID',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: const Icon(PhosphorIconsRegular.downloadSimple, size: 14, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ─── Sales Target tab ────────────────────────────────────────────────────────

class _EmployeeTargetTab extends StatelessWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeTargetTab({required this.profile, required this.state});

  // SERVICE_VOLUME targets are rupee quotas; PRODUCT_SALES_COUNT is a unit
  // count. The old card printed both as bare numbers, so a revenue target
  // rendered as "50000" with no currency anywhere on the screen.
  bool _isCurrency(String type) => type != 'PRODUCT_SALES_COUNT';

  String _fmt(String type, double value) =>
      _isCurrency(type) ? '₹${value.toStringAsFixed(0)}' : value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final targets = [...state.salesTargets]
      ..sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));
    final active = targets.where((t) => t.status == 'ACTIVE').toList();
    final achieved = targets.where((t) => t.status == 'ACHIEVED').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Targets',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A), letterSpacing: -0.5),
              ),
              const SizedBox(height: 2),
              const Text(
                'Track your revenue quotas set by your manager.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              if (active.isNotEmpty) ...[
                _buildHeroTarget(active.first),
                const SizedBox(height: 18),
              ],

              if (targets.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(PhosphorIconsRegular.flag, size: 38, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 12),
                        Text(
                          'No sales targets set yet.',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your manager can set one from the Employees tab.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Targets',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$achieved of ${targets.length} achieved',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < targets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildTargetCard(targets[i]),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // The one target actually in play gets the hero treatment - it's the number
  // the employee is working against today.
  Widget _buildHeroTarget(SalesTarget target) {
    final pct = (target.progressFraction * 100).clamp(0, 999);
    final remaining = (target.targetValue - target.progressValue).clamp(0.0, double.infinity);
    final daysLeft = target.endDate == null ? null : target.endDate!.difference(DateTime.now()).inDays;

    return Container(
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
                child: const Icon(PhosphorIconsRegular.target, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _targetTypeLabel(target.type).toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFC7D2FE), letterSpacing: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(target.type, target.progressValue),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              ),
              const SizedBox(width: 6),
              Text(
                'of ${_fmt(target.type, target.targetValue)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC7D2FE)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroStat('Completed', '${pct.toStringAsFixed(0)}%'),
              const SizedBox(width: 10),
              _heroStat('To target', _fmt(target.type, remaining)),
              const SizedBox(width: 10),
              _heroStat(
                'Days left',
                daysLeft == null ? '-' : (daysLeft < 0 ? 'Ended' : '$daysLeft'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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

  Widget _buildTargetCard(SalesTarget target) {
    Color statusColor = AppTheme.primaryBlue;
    Color statusBg = AppTheme.primaryLight;
    IconData statusIcon = PhosphorIconsRegular.target;
    if (target.status == 'ACHIEVED') {
      statusColor = AppTheme.accentGreen;
      statusBg = AppTheme.accentGreenBg;
      statusIcon = PhosphorIconsRegular.checkCircle;
    }
    if (target.status == 'FAILED') {
      statusColor = AppTheme.accentRed;
      statusBg = AppTheme.accentRedBg;
      statusIcon = PhosphorIconsRegular.xCircle;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(statusIcon, size: 16, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetTypeLabel(target.type),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_formatDate(target.startDate)} - ${_formatDate(target.endDate)}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _statusBadge(target.status, statusBg, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Achieved',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(target.type, target.progressValue),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -0.5),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Target',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmt(target.type, target.targetValue),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: target.progressFraction.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(target.progressFraction * 100).toStringAsFixed(0)}% completed',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'APPROVED':
        return PhosphorIconsRegular.checkCircle;
      case 'REJECTED':
        return PhosphorIconsRegular.xCircle;
      default:
        return PhosphorIconsRegular.hourglassMedium;
    }
  }

  Widget _buildRequestCard(BuildContext context, DiscountRequest req) {
    final bill = req.billId == null ? null : state.bills.where((b) => b.id == req.billId);
    final matchedBill = (bill != null && bill.isNotEmpty) ? bill.first : null;
    final statusColor = _statusColor(req.status);
    final statusBackground = _statusBg(req.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: statusBackground, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(_statusIcon(req.status), size: 16, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      matchedBill != null
                          ? '${matchedBill.customerName ?? "Customer"} - ${matchedBill.invoiceNumber}'
                          : 'General request',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatDate(req.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _statusBadge(req.status, statusBackground, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.tag, size: 15, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  '₹${req.requestedDiscount.toStringAsFixed(0)} off',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                if (req.overridePrice != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Override ₹${req.overridePrice!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            req.reason,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
          ),
          if (req.status == 'APPROVED' && req.authorizedCode != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
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
                        const Text(
                          'Authorization Code',
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          req.authorizedCode!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 1),
                        ),
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

  Widget _statTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = [...state.discountRequests]
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final pending = requests.where((r) => r.status == 'PENDING').length;
    final approved = requests.where((r) => r.status == 'APPROVED').length;
    final rejected = requests.where((r) => r.status == 'REJECTED').length;

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discount Requests',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A), letterSpacing: -0.5),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ask your manager to approve a discount beyond what you can give.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _showNewRequestDialog(context, ref),
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
                            Text('New Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    _statTile(
                      icon: PhosphorIconsRegular.hourglassMedium,
                      iconBg: AppTheme.accentAmberBg,
                      iconColor: AppTheme.accentAmber,
                      label: 'Pending',
                      value: '$pending',
                    ),
                    const SizedBox(width: 8),
                    _statTile(
                      icon: PhosphorIconsRegular.checkCircle,
                      iconBg: AppTheme.accentGreenBg,
                      iconColor: AppTheme.accentGreen,
                      label: 'Approved',
                      value: '$approved',
                    ),
                    const SizedBox(width: 8),
                    _statTile(
                      icon: PhosphorIconsRegular.xCircle,
                      iconBg: AppTheme.accentRedBg,
                      iconColor: AppTheme.accentRed,
                      label: 'Rejected',
                      value: '$rejected',
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (requests.isEmpty)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(32.0),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(PhosphorIconsRegular.tag, size: 38, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text(
                            'No discount requests yet.',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Use New Request when a client needs more than you can give.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  const Text(
                    'Your Requests',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  for (final req in requests) _buildRequestCard(context, req),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
