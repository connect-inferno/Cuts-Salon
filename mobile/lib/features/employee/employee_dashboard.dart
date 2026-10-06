import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../data/app_data_provider.dart';
import '../../data/salary_provider.dart';
import '../../data/models.dart';
import '../auth/auth_provider.dart';
import '../../firebase/salon_auth.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_page_switcher.dart';
import '../../widgets/app_settings_page.dart';
import '../../widgets/app_sub_page.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/add_customer_page.dart';
import '../../widgets/dues_view.dart';
import 'employee_payment_requests_view.dart';
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

/// Month names, at the top level because the payout statements, the greeting
/// line and the pay-period header all print them and three local copies had
/// already started to drift.
const kMonthFullNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

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

/// The four places a stylist actually works out of.
///
/// This used to be eight equally-ranked tabs behind a bottom bar that
/// reached four of them and a "More" drawer that reached the rest - the
/// same flat sprawl the owner side had. Everything that isn't one of these
/// four is now a section of one of their settings screens (profile and
/// attendance under Home, discount requests under Billing, targets under
/// Earnings) or a drawer destination.
enum EmployeeTab { home, billing, clients, earnings }

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  EmployeeTab _activeTab = EmployeeTab.home;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeTab.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchToTab(EmployeeTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
    if (_pageController.hasClients) {
      final current = _pageController.page?.round() ?? _activeTab.index;
      if ((tab.index - current).abs() > 1) {
        _pageController.jumpToPage(tab.index);
      } else {
        _pageController.animateToPage(
          tab.index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  int _myPendingDiscounts(EmployeeProfile profile, AppData state) => state.discountRequests
      .where((r) => r.status == 'PENDING' && r.requestedBy == profile.id)
      .length;

  // ─── Settings ─────────────────────────────────────────────────────────

  /// Everything about *me*, on one screen - the same gear, in the same
  /// place, behaving the same way as the owner's.
  void _openMyAccountSettings(BuildContext context, EmployeeProfile profile, AppData state) {
    final now = DateTime.now();
    final presentThisMonth = state.attendance
        .where((a) =>
            a.employeeId == profile.id &&
            a.date != null &&
            a.date!.month == now.month &&
            a.date!.year == now.year &&
            (a.status == 'PRESENT' || a.status == 'LATE'))
        .length;

    openAppSettings(
      context,
      title: 'My Account',
      subtitle: profile.name,
      sections: [
        AppSettingsSection(
          icon: PhosphorIconsRegular.userCircle,
          label: 'Profile',
          description: 'Your contact details and password.',
          builder: (_) => _EmployeeProfileTab(profile: profile, state: state),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.calendarCheck,
          label: 'Attendance',
          description:
              '$presentThisMonth day${presentThisMonth == 1 ? '' : 's'} logged this month. Clock in and out from Home.',
          builder: (_) => _EmployeeAttendanceTab(profile: profile, state: state),
        ),
      ],
    );
  }

  /// Client-side money, from the counter's point of view.
  ///
  /// firestore.rules lets an active employee create a payment
  /// (`payments/{paymentId}: allow read, create: if isActiveEmployee()`),
  /// so a stylist settling a balance when the client is standing in front
  /// of them is a supported flow, not an owner-only one - it just had
  /// nowhere to happen from.
  void _openClientSettings(BuildContext context, AppData state) {
    final owing = state.bills.where((b) => !b.isFullyPaid).map((b) => b.customerId).toSet().length;
    final outstanding = state.bills.fold<double>(0, (s, b) => s + b.amountDue);

    openAppSettings(
      context,
      title: 'Client Settings',
      subtitle: 'Client records and their money',
      sections: [
        AppSettingsSection(
          icon: PhosphorIconsRegular.handCoins,
          label: 'Outstanding',
          description: owing > 0
              ? '₹${outstanding.round()} still to collect, across $owing client${owing == 1 ? '' : 's'}. '
                  'Collecting one sends a request to your owner to approve.'
              : 'No client owes anything right now.',
          // requestOnly: staff raise a settlement request instead of
          // recording the payment. firestore.rules enforces the same split,
          // so this is the button telling the truth about what it can do.
          builder: (_) => const DuesView(requestOnly: true),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.paperPlaneTilt,
          label: 'My requests',
          description:
              'Settlement requests you have sent, and what your owner decided.',
          builder: (_) => const EmployeePaymentRequestsView(),
        ),
      ],
    );
  }

  /// The bell, wired the same way from every page.
  void _openNotifications(BuildContext context, EmployeeProfile profile, AppData state) {
    if (_myPendingDiscounts(profile, state) > 0) {
      openAppSubPage(
        context,
        title: 'Discount Requests',
        subtitle: 'Your requests awaiting approval',
        child: _EmployeeDiscountRequestsTab(profile: profile, state: state),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No new notifications'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── Drawer ───────────────────────────────────────────────────────────

  Widget _buildDrawer(
    BuildContext context,
    EmployeeProfile profile,
    AppData state, {
    required bool isModal,
  }) {
    final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final pending = _myPendingDiscounts(profile, state);

    // Builds the page from live app data, not the `state` captured when the
    // menu was tapped. A pushed route doesn't rebuild with its parent, so a
    // snapshot went stale the moment anything changed on it: a discount
    // request just sent didn't appear, and clocking in on the Attendance
    // page left it still offering "Clock In".
    void go(String title, String subtitle, Widget Function(AppData live) page) {
      if (isModal) Navigator.pop(context);
      openAppSubPage(
        context,
        title: title,
        subtitle: subtitle,
        child: Consumer(builder: (_, ref, __) => page(ref.watch(appDataProvider).valueOrNull ?? state)),
      );
    }

    void jump(EmployeeTab tab) {
      if (isModal) Navigator.pop(context);
      _switchToTab(tab);
    }

    return AppDrawer(
      isModal: isModal,
      title: salonName,
      subtitle: '${profile.roleTitle} · ${profile.name}',
      avatarInitials: profile.name
          .split(' ')
          .where((n) => n.isNotEmpty)
          .map((n) => n[0].toUpperCase())
          .take(2)
          .join(),
      onLogout: () {
        if (isModal) Navigator.pop(context);
        ref.read(authControllerProvider.notifier).logout();
      },
      sections: [
        AppDrawerSection(
          title: 'Go to',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.house,
              label: 'Home',
              selected: _activeTab == EmployeeTab.home,
              onTap: () => jump(EmployeeTab.home),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.receipt,
              label: 'Billing',
              selected: _activeTab == EmployeeTab.billing,
              onTap: () => jump(EmployeeTab.billing),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.usersThree,
              label: 'Clients',
              selected: _activeTab == EmployeeTab.clients,
              onTap: () => jump(EmployeeTab.clients),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.wallet,
              label: 'Earnings',
              selected: _activeTab == EmployeeTab.earnings,
              onTap: () => jump(EmployeeTab.earnings),
            ),
          ],
        ),
        AppDrawerSection(
          title: 'Mine',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.calendarBlank,
              label: 'Attendance',
              onTap: () => go('Attendance', 'Your shift history',
                  (live) => _EmployeeAttendanceTab(profile: profile, state: live)),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.chartLineUp,
              label: 'Sales Targets',
              onTap: () => go('Sales Targets', 'Quotas set by your manager',
                  (live) => _EmployeeTargetTab(profile: profile, state: live)),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.sealPercent,
              label: 'Discount Requests',
              badgeCount: pending,
              onTap: () => go('Discount Requests', 'Your requests and their status',
                  (live) => _EmployeeDiscountRequestsTab(profile: profile, state: live)),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.userCircle,
              label: 'Profile',
              onTap: () => go('Profile', 'Your details and password',
                  (live) => _EmployeeProfileTab(profile: profile, state: live)),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────

  /// Five slots, five real destinations - identical in shape to the owner's.
  /// The protruding "+" is gone here too: its sheet only jumped to pages the
  /// bar already reached.
  Widget _buildNavBar(BuildContext context, int pendingDiscountCount) {
    return LiquidNavBar(
      selectedIndex: _activeTab.index,
      items: [
        LiquidNavItem(
          icon: PhosphorIconsRegular.house,
          activeIcon: PhosphorIconsFill.house,
          label: 'Home',
          onTap: () => _switchToTab(EmployeeTab.home),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.receipt,
          activeIcon: PhosphorIconsFill.receipt,
          label: 'Billing',
          onTap: () => _switchToTab(EmployeeTab.billing),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.usersThree,
          activeIcon: PhosphorIconsFill.usersThree,
          label: 'Clients',
          onTap: () => _switchToTab(EmployeeTab.clients),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.wallet,
          activeIcon: PhosphorIconsFill.wallet,
          label: 'Earnings',
          onTap: () => _switchToTab(EmployeeTab.earnings),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.list,
          activeIcon: PhosphorIconsFill.list,
          label: 'Menu',
          badgeCount: pendingDiscountCount,
          // Scaffold.of(context), not a GlobalKey: this callback is built
          // inside the Scaffold's own bottomNavigationBar slot, so the
          // lookup cannot miss. The key's currentState reads null whenever
          // the AsyncValue flips through `loading` and remounts the
          // Scaffold, which silently made this button do nothing.
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
      ],
    );
  }

  // ─── Shell ────────────────────────────────────────────────────────────

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
    final pending = _myPendingDiscounts(empProfile, state);

    // No AppBar. It used to draw a salon name, a bell that only opened the
    // drawer, and an avatar that jumped to a Profile tab - a second header
    // above whatever header each tab drew for itself. Every page now wears
    // the shared AppPageHeader instead, exactly as on the owner side.
    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      extendBody: isMobile,
      drawer: isMobile ? _buildDrawer(context, empProfile, state, isModal: true) : null,
      bottomNavigationBar:
          isMobile ? Builder(builder: (ctx) => _buildNavBar(ctx, pending)) : null,
      body: SafeArea(
        bottom: !isMobile,
        child: isMobile
            // See the owner dashboard: content is meant to show through the
            // glass, so the inset lives on each tab's scrollable.
            ? PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) => setState(() => _activeTab = EmployeeTab.values[index]),
                children: _buildPages(context, empProfile, state),
              )
            : Row(
                children: [
                  _buildDrawer(context, empProfile, state, isModal: false),
                  Expanded(
                    child: AppPageSwitcher(
                      child: _buildPages(context, empProfile, state)[_activeTab.index],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Wraps each tab in the shared header rather than letting the tab draw
  /// its own, so the four pages cannot disagree about where the title,
  /// the bell and the gear live.
  Widget _page({
    Key? key,
    required String title,
    String? subtitle,
    List<AppPageAction> actions = const [],
    required Widget child,
  }) {
    return Container(
      key: key,
      color: AppTheme.bgSurface,
      child: Column(
        children: [
          AppPageHeader(title: title, subtitle: subtitle, actions: actions),
          Expanded(child: child),
        ],
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context, EmployeeProfile profile, AppData state) {
    final pending = _myPendingDiscounts(profile, state);
    final now = DateTime.now();

    final myBillsToday = state.bills
        .where((b) =>
            b.createdAt != null &&
            _isSameDay(b.createdAt!, now) &&
            b.items.any((i) => i.employeeId == profile.id))
        .length;

    final pendingCommission = state.pendingCommissionFor(profile.id).total;

    return [
      _page(
        key: const ValueKey('home'),
        title: 'Home',
        subtitle: 'Good ${_greeting(now.hour)}, ${profile.name.split(' ').first}',
        actions: [
          AppPageAction(
            icon: PhosphorIconsRegular.bell,
            tooltip: 'Notifications',
            badgeCount: pending,
            onTap: () => _openNotifications(context, profile, state),
          ),
          appSettingsAction(
            tooltip: 'My account',
            onTap: () => _openMyAccountSettings(context, profile, state),
          ),
        ],
        child: _EmployeeDashboardTab(
          profile: profile,
          state: state,
          onOpenBilling: () => _switchToTab(EmployeeTab.billing),
        ),
      ),
      _page(
        key: const ValueKey('billing'),
        title: 'Billing',
        subtitle: myBillsToday > 0
            ? '$myBillsToday bill${myBillsToday == 1 ? '' : 's'} by you today'
            : 'No bills by you yet today',
        // No gear: its one section, Discount Requests, is reached from the
        // drawer and from the bell on Clients, so nothing is stranded.
        child: _EmployeeBillingTab(profile: profile),
      ),
      _page(
        key: const ValueKey('clients'),
        title: 'Clients',
        subtitle: 'The clients you have handled',
        actions: [
          AppPageAction(
            icon: PhosphorIconsRegular.bell,
            tooltip: 'Notifications',
            badgeCount: pending,
            onTap: () => _openNotifications(context, profile, state),
          ),
          appSettingsAction(
            tooltip: 'Client settings',
            onTap: () => _openClientSettings(context, state),
          ),
        ],
        child: _EmployeeCustomersTab(profile: profile),
      ),
      _page(
        key: const ValueKey('earnings'),
        title: 'Earnings',
        subtitle: pendingCommission > 0
            ? '₹${pendingCommission.round()} commission pending'
            : 'No commission pending',
        // No gear: its one section, Targets, is reached from the drawer.
        child: _EmployeeSalaryTab(profile: profile, state: state),
      ),
    ];
  }
}

// ─── Dashboard home tab ─────────────────────────────────────────────────────

class _EmployeeDashboardTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final AppData state;
  // Named for where it goes. `onTabSelected(3)` meant this widget had to
  // know that 3 was Billing - numbering owned by another class that broke
  // silently whenever the tab list was reordered.
  final VoidCallback onOpenBilling;

  const _EmployeeDashboardTab({
    required this.profile,
    required this.state,
    required this.onOpenBilling,
  });

  /// Where this employee stands against their target for the current month.
  ///
  /// `state.salesTargets` is already scoped to the signed-in user by
  /// `listSalesTargets(employeeId: selfId)`, and already loaded as part of
  /// the AppData snapshot - so this card costs no extra Firestore read.
  Widget _buildMonthlyTargetCard() {
    final now = DateTime.now();
    // Active targets covering today. endDate is what makes a target
    // "this month"; one without dates is treated as current rather than
    // hidden, since a target nobody can see is worse than one shown early.
    final current = state.salesTargets.where((t) {
      if (t.status != 'ACTIVE') return false;
      final end = t.endDate;
      final start = t.startDate;
      if (end != null && end.isBefore(DateTime(now.year, now.month, now.day))) {
        return false;
      }
      if (start != null && start.isAfter(now)) return false;
      return true;
    }).toList()
      // Revenue first: it is the headline number when someone carries both.
      ..sort((a, b) => a.type == 'PRODUCT_SALES_COUNT' ? 1 : -1);

    if (current.isEmpty) return _emptyTargetCard();

    return Column(
      children: [
        for (var i = 0; i < current.length && i < 2; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          // The same card the Targets tab shows. `now` is no longer needed
          // here: the card works out its own days-left from the target.
          TargetHeroCard(target: current[i]),
        ],
      ],
    );
  }

  Widget _emptyTargetCard() {
    // Shown rather than hidden: every employee here is meant to have one, so
    // a missing target is information, not a reason to render nothing.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              PhosphorIconsRegular.target,
              size: 18,
              color: AppTheme.slateLight,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Target',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No target set for this month yet.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slateLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut == null;
    final shiftDone = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut != null;
    final firstName = profile.name.split(' ').first;

    final myBills = state.bills.where((b) => b.items.any((i) => i.employeeId == profile.id)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final recentBills = myBills.take(5).toList();

    // Stats
    final todayBills = myBills.where((b) => b.createdAt != null && _isSameDay(b.createdAt!, now)).toList();
    final todayCustomers = todayBills.map((b) => b.customerId).toSet().length;
    // What this stylist earned today: the commission on their own lines.
    // This used to sum the whole bills' finalAmount - GST and colleagues'
    // lines included - so a ₹1,180 bill read as ₹1,180 "earned" when the
    // stylist's commission on it was ₹120.
    final todayEarned = todayBills.fold<double>(
      0,
      (s, b) => s + b.items.where((i) => i.employeeId == profile.id).fold<double>(0, (t, i) => t + i.calculatedCommission),
    );

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, LiquidNavBar.barInset),
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
                    '₹${todayEarned.toStringAsFixed(0)}',
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

          // 3b. Monthly target. The salon runs on monthly targets, so where
          // someone stands against theirs belongs on the screen they open
          // every morning, not only on the Target tab behind the menu.
          _buildMonthlyTargetCard(),
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
                    // One shift a day - the attendance rules refuse a second
                    // clock-in, so offering the button only produced an error.
                    onPressed: shiftDone ? null : () => _toggleClock(context, ref, isClockedIn),
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
                      shiftDone ? 'Shift finished for today' : (isClockedIn ? 'Clock Out' : 'Clock In'),
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
            onTap: onOpenBilling,
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
                      onTap: onOpenBilling,
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
          const SizedBox(height: 88),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRecord = _todayAttendance(state, profile.id);
    final isClockedIn = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut == null;
    final shiftDone = todayRecord != null && todayRecord.clockIn != null && todayRecord.clockOut != null;
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
            // stretch, not start. With start the clock card sized itself to
            // the 120px circle inside it, so it sat about two thirds the
            // width of the summary chips directly below - which read as a
            // broken layout rather than as a deliberate shape.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title removed: the page this sits in already names it.

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
                      // See the Home shift card: one shift a day.
                      onTap: shiftDone ? null : () => _toggleClock(context, ref, isClockedIn),
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
                              shiftDone ? 'Done today' : (isClockedIn ? 'Clock Out' : 'Clock In'),
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
                  _buildAttendChip('Present', _days(presentDays), AppTheme.accentGreen, AppTheme.accentGreenBg),
                  const SizedBox(width: 10),
                  _buildAttendChip('Late', _days(lateDays), AppTheme.accentAmber, AppTheme.accentAmberBg),
                  const SizedBox(width: 10),
                  _buildAttendChip('Absent', _days(absentDays), AppTheme.accentRed, AppTheme.accentRedBg),
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

  /// "1 day", not "1 days" - the chips sit side by side, so the wrong
  /// plural on one of three is impossible not to read.
  static String _days(int n) => '$n day${n == 1 ? '' : 's'}';

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
  final EmployeeProfile profile;

  const _EmployeeCustomersTab({required this.profile});

  @override
  State<_EmployeeCustomersTab> createState() => _EmployeeCustomersTabState();
}

class _EmployeeCustomersTabState extends State<_EmployeeCustomersTab> {
  String _searchQuery = '';
  String _filter = 'All';

  /// The bills this staff member worked on, grouped by client.
  ///
  /// Attribution is per line item, not per bill: two stylists can share one
  /// bill, and whoever happens to be on the first line did not necessarily
  /// do the rest of it. A bill counts as theirs if any line carries their id.
  ///
  /// Derived from the AppData snapshot that is already loaded, so scoping the
  /// directory this way costs no Firestore read.
  Map<String, List<Bill>> _myBillsByCustomer(AppData state) {
    final byCustomer = <String, List<Bill>>{};
    for (final bill in state.bills) {
      if (!bill.items.any((i) => i.employeeId == widget.profile.id)) continue;
      (byCustomer[bill.customerId] ??= []).add(bill);
    }
    for (final bills in byCustomer.values) {
      bills.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }
    return byCustomer;
  }

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

    // Only the clients this staff member has actually worked on. The whole
    // salon directory used to be listed here, which made "my clients" a list
    // of people a stylist may never have met - and gave every staff member a
    // roster of the salon's entire clientele.
    final myBills = _myBillsByCustomer(state);
    final mine = state.customers.where((c) => myBills.containsKey(c.id)).toList();
    final returningCount = mine.where((c) => (myBills[c.id]?.length ?? 0) > 1).length;

    final filtered = mine.where((c) {
      final matches = q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q);
      if (!matches) return false;

      // "Returning" means returning *to this stylist* now, which is the
      // only sense of it this page can honestly claim.
      if (_filter == 'Returning') return (myBills[c.id]?.length ?? 0) > 1;
      return true;
    }).toList()
      ..sort((a, b) => (b.lastVisitAt ?? DateTime(0)).compareTo(a.lastVisitAt ?? DateTime(0)));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, LiquidNavBar.barInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title removed: the page this sits in already names it.

          // Summary tiles
          Row(
            children: [
              _summaryTile(
                icon: PhosphorIconsRegular.usersThree,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: const Color(0xFF4F46E5),
                label: 'Handled',
                value: '${mine.length}',
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
                _filterChip('All', mine.length),
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
                    'No clients yet.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Clients you bill appear here, with the visits you handled.',
                    textAlign: TextAlign.center,
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
                    _clientRow(context, filtered[i], i, myBills[filtered[i].id] ?? const []),
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

  Widget _clientRow(BuildContext context, Customer c, int idx, List<Bill> myBills) {
    const avatarBgs = [Color(0xFFEEF2FF), Color(0xFFFEF3C7), Color(0xFFF5F3FF), Color(0xFFCCFBF1), Color(0xFFFCE7F3)];
    const avatarFgs = [Color(0xFF4F46E5), Color(0xFFD97706), Color(0xFF7C3AED), Color(0xFF0D9488), Color(0xFFDB2777)];
    final bg = avatarBgs[idx % avatarBgs.length];
    final fg = avatarFgs[idx % avatarFgs.length];

    return InkWell(
      onTap: () => openAppSubPage(
        context,
        title: c.name,
        subtitle: '${myBills.length} visit${myBills.length == 1 ? '' : 's'} you handled',
        child: _MyClientHistoryView(
          customer: c,
          bills: myBills,
          employeeId: widget.profile.id,
        ),
      ),
      child: Padding(
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
                    // The VIP chip used to sit here. It is an owner-side
                    // flag nobody on the floor sets or acts on, and on a row
                    // this narrow it crowded out the name it was attached to.
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
                        _lastHandled(myBills),
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
              // This stylist's own billings for the client, not the
              // customer document's salon-wide totalSpent/visitCount - on a
              // page scoped to "clients I handled" the salon figure would be
              // claiming credit for someone else's work.
              Text(
                '₹${_myRevenueFor(myBills).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                '${myBills.length} visit${myBills.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  double _myRevenueFor(List<Bill> bills) => bills.fold<double>(
        0,
        (sum, b) =>
            sum +
            b.items
                .where((i) => i.employeeId == widget.profile.id)
                .fold<double>(0, (s, i) => s + (i.unitPrice * i.quantity - i.discountAmount)),
      );

  /// The last visit shown on the row is the last one *this* stylist handled.
  String _lastHandled(List<Bill> bills) =>
      bills.isEmpty || bills.first.createdAt == null ? 'Never' : _formatDate(bills.first.createdAt);
}

/// One client's visits, as far as this staff member is concerned.
///
/// Only the bills carrying one of their line items, and within each bill only
/// the lines they performed - a shared bill shows the stylist their own half,
/// not the colleague's. Everything comes from the loaded snapshot.
class _MyClientHistoryView extends StatelessWidget {
  final Customer customer;
  final List<Bill> bills;
  final String employeeId;

  const _MyClientHistoryView({
    required this.customer,
    required this.bills,
    required this.employeeId,
  });

  @override
  Widget build(BuildContext context) {
    final myTotal = bills.fold<double>(
      0,
      (sum, b) =>
          sum +
          b.items
              .where((i) => i.employeeId == employeeId)
              .fold<double>(0, (s, i) => s + (i.unitPrice * i.quantity - i.discountAmount)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BILLED BY YOU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '\u20B9${myTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Across ${bills.length} visit${bills.length == 1 ? '' : 's'} · ${customer.phone}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Visits you handled',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          for (final bill in bills) ...[
            _billCard(bill),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _billCard(Bill bill) {
    final mine = bill.items.where((i) => i.employeeId == employeeId).toList();
    final myTotal = mine.fold<double>(
      0,
      (s, i) => s + (i.unitPrice * i.quantity - i.discountAmount),
    );
    // A bill can carry another stylist's lines too; saying so is what stops
    // the per-line figure below reading like a wrong bill total.
    final shared = mine.length != bill.items.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.invoiceNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(bill.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Text(
                '\u20B9${myTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.dotOutline, size: 13, color: Color(0xFFCBD5E1)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.serviceName ?? item.productName ?? 'Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475467), fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '\u20B9${(item.unitPrice * item.quantity - item.discountAmount).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          if (shared) ...[
            const SizedBox(height: 6),
            Text(
              'Shared bill \u2014 \u20B9${bill.finalAmount.toStringAsFixed(0)} in total, including a colleague\'s lines.',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
            ),
          ],
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
  // Products & Retail is a disclosure, collapsed by default, matching the
  // owner's POS: the catalog otherwise pushes payment and the total off the
  // screen. Purely local UI state - the list comes from the AppData
  // snapshot already loaded, so opening it costs no Firestore read.
  bool _productsExpanded = false;
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
      // Billing is the form and nothing else for staff. A bill history here
      // would be a second place to look for the same records - a staff
      // member's history is the clients they handled, so it lives on the
      // Clients page beside the client it belongs to.
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

    // No Stack. The total and its button used to be Positioned at a fixed
    // 90px off the bottom, floating over whatever happened to be scrolled
    // under them - so on a short catalog they sat on top of the last service
    // row, and the 220px of blank padding that compensated for them left a
    // hole at the end of the page. They are the last thing on the page now:
    // you scroll to the total, which is also the order the task happens in.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, LiquidNavBar.barInset),
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
                  // Opened unconditionally. It used to be gated on the salon
                  // already having clients, which with an "add new" action in
                  // the sheet would leave the very first client unaddable -
                  // no clients meant the sheet that creates one never opened.
                  final c = await showSearchablePicker<Customer>(
                    context: context,
                    title: 'Select Customer',
                    items: state.customers,
                    labelOf: (item) => item.name,
                    subtitleOf: (item) => item.phone,
                    createLabel: 'Add new customer',
                    onCreate: (ctx) => openAppSubPage<Customer>(
                      ctx,
                      title: 'Add Customer',
                      subtitle: 'Save their details to start tracking visits',
                      child: AddCustomerPage(branches: state.branches),
                    ),
                  );
                  if (c != null) setState(() => _selectedCustomerId = c.id);
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

              // 4. Products & Retail Section - a collapsed disclosure, the
              // same shape as the owner's. The "N Selected" badge stays in
              // the header, so nothing already on the bill is hidden by
              // closing it.
              InkWell(
                onTap: () => setState(
                  () => _productsExpanded = !_productsExpanded,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
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
                          color: productItemCount > 0
                              ? const Color(0xFFEEF2FF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$productItemCount Selected',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: productItemCount > 0
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
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
                    allProducts.isEmpty
                        ? 'No products in inventory yet.'
                        : 'Tap to browse ${allProducts.length} product${allProducts.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              if (_productsExpanded) ...[
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
              ],
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

              // Payment options row (Cash, UPI/QR, Pending). CARD was
              // removed - the salon does not take card payments. Bills
              // already stored with paymentMethod 'CARD' still read back
              // fine; this only stops new ones being created.
              Row(
                children: [
                  _buildPaymentCard('CASH', 'Cash', PhosphorIconsRegular.money),
                  const SizedBox(width: 8),
                  _buildPaymentCard('UPI', 'UPI / QR', PhosphorIconsRegular.qrCode),
                  const SizedBox(width: 8),
                  _buildPaymentCard('PENDING', 'Pending', PhosphorIconsRegular.clockCountdown),
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

              const SizedBox(height: 16),

              // Total + submit, in the flow.
              Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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

              // Clears the floating nav bar, which the page scrolls under.
              const SizedBox(height: 24),
        ],
      ),
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
                for (final m in ['CASH', 'UPI'])
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

class _EmployeeSalaryTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeSalaryTab({required this.profile, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final payouts = [
      ...(ref.watch(salaryRecordsProvider).valueOrNull ?? const <SalaryRecord>[])
          .where((r) => r.employeeId == profile.id)
    ]
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, LiquidNavBar.barInset),
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
                  // Title removed: the page this sits in already names it.
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
            children: [
              const Column(
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
                    'Past finalized statements',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              // "View All" was a plain Text that did nothing. The card below
              // it shows six months at most, so on any staff member who has
              // been here longer than that the rest was simply unreachable.
              if (payouts.length > 6)
                InkWell(
                  onTap: () => openAppSubPage(
                    context,
                    title: 'Payout History',
                    subtitle: '${payouts.length} statement${payouts.length == 1 ? '' : 's'}',
                    child: _AllPayoutsView(payouts: payouts),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'View All',
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
                // A one-line grey sentence in a full-width card read as a
                // rendering failure rather than as "nothing here yet".
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: [
                        Icon(PhosphorIconsRegular.receipt, size: 28, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 10),
                        Text(
                          'No payouts recorded yet',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Statements appear here once your owner finalises a month.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (int i = 0; i < payouts.length && i < 6; i++) ...[
                        if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 18),
                        _buildPayoutRow(
                          '${monthFullNames[payouts[i].month - 1]} ${payouts[i].year}',
                          payouts[i].status,
                          '₹${payouts[i].totalPaid.toStringAsFixed(0)}',
                        ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 88),
        ],
      ),
    );
  }

  /// One month's statement.
  ///
  /// The badge now reads the record's real status. It used to be hardcoded
  /// to a green "PAID" while the line underneath said "Draft - not yet paid",
  /// so a statement that had not been paid claimed on its own row that it
  /// had. The period is one line too: it carried a \n and sat in a Row beside
  /// the badge, which pushed the badge off its baseline.
  Widget _buildPayoutRow(String period, String status, String amount) {
    final paid = status == 'PAID';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: paid ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              paid ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.hourglass,
              size: 18,
              color: paid ? const Color(0xFF10B981) : const Color(0xFF64748B),
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
                      period,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: paid ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      paid ? 'PAID' : 'DRAFT',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: paid ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                paid ? 'Settled' : 'Not yet paid',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        // The download button that used to sit here downloaded nothing -
        // there is no statement file to fetch, only the figures already on
        // this row.
      ],
    );
  }
}

/// Every payout statement, not just the six the Earnings card has room for.
///
/// Reads nothing of its own: salary records are already loaded by the
/// salary provider that the Earnings tab watches, and this is handed the
/// same list.
class _AllPayoutsView extends StatelessWidget {
  final List<SalaryRecord> payouts;

  const _AllPayoutsView({required this.payouts});

  @override
  Widget build(BuildContext context) {
    final total = payouts
        .where((r) => r.status == 'PAID')
        .fold<double>(0, (sum, r) => sum + r.totalPaid);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAID OUT TO DATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '\u20B9${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Across ${payouts.length} statement${payouts.length == 1 ? '' : 's'}. Drafts are not counted.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < payouts.length; i++) ...[
                  if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 18),
                  _payoutRow(payouts[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _payoutRow(SalaryRecord r) {
    final paid = r.status == 'PAID';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${kMonthFullNames[r.month - 1]} ${r.year}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'Base \u20B9${r.baseSalary.toStringAsFixed(0)} · '
                'Commission \u20B9${r.commissionEarned.toStringAsFixed(0)}'
                '${r.deductions > 0 ? ' · Deductions \u20B9${r.deductions.toStringAsFixed(0)}' : ''}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\u20B9${r.totalPaid.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(
              paid ? 'Paid' : 'Draft',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: paid ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


/// A SERVICE_VOLUME target is a rupee quota; PRODUCT_SALES_COUNT is a count
/// of units. Kept at the top level because both the home screen card and the
/// Target tab format targets, and a revenue figure printed without a currency
/// symbol is a bug that has already happened once here.
bool targetIsCurrency(String type) => type != 'PRODUCT_SALES_COUNT';

String formatTargetValue(String type, double value) => targetIsCurrency(type)
    ? '\u20B9${value.toStringAsFixed(0)}'
    : value.toStringAsFixed(0);

String targetTypeLabel(String type) =>
    type == 'PRODUCT_SALES_COUNT' ? 'Product sales' : 'Service revenue';

/// The sales-target card, as the Targets tab draws it.
///
/// Lifted out of _EmployeeTargetTab so Home can show the same card. Home used
/// to draw its own smaller white version of the same numbers, so the one
/// target an employee has appeared twice in the app in two different shapes -
/// and the home version was the one that dropped the pacing and the days
/// left, which is the half that tells you whether to worry.
class TargetHeroCard extends StatelessWidget {
  final SalesTarget target;

  const TargetHeroCard({super.key, required this.target});

  String _fmt(String type, double value) => formatTargetValue(type, value);

  @override
  Widget build(BuildContext context) {
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
}

// ─── Sales Target tab ────────────────────────────────────────────────────────

class _EmployeeTargetTab extends StatelessWidget {
  final EmployeeProfile profile;
  final AppData state;

  const _EmployeeTargetTab({required this.profile, required this.state});

  // Shared with the home screen's target card, so the two can never disagree
  // about whether a target is rupees or a unit count - see formatTargetValue.
  String _fmt(String type, double value) => formatTargetValue(type, value);

  @override
  Widget build(BuildContext context) {
    final targets = [...state.salesTargets]
      ..sort((a, b) => (b.startDate ?? DateTime(0)).compareTo(a.startDate ?? DateTime(0)));
    final active = targets.where((t) => t.status == 'ACTIVE').toList();
    final achieved = targets.where((t) => t.status == 'ACHIEVED').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32 + LiquidNavBar.barInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title removed: the page this sits in already names it.

              if (active.isNotEmpty) ...[
                TargetHeroCard(target: active.first),
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

/// Profile, as a section of My Account settings.
///
/// It used to carry a six-row menu linking to Attendance, Commission,
/// Earnings, Targets and Discount Requests - a signpost duplicating the
/// nav, which is exactly the sprawl this restructure removes. What is left
/// is the thing only this screen does: show your details and change your
/// password.
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

              // Just the one row this screen owns. The five navigation
              // tiles that used to sit here pointed at Attendance,
              // Earnings, Targets and Discount Requests - all reachable
              // from the nav, the drawer and their own section gears.
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: _buildMenuTile(
                  icon: PhosphorIconsRegular.lockKey,
                  iconColor: AppTheme.slateMedium,
                  iconBg: const Color(0xFFF1F5F9),
                  title: 'Change Password',
                  subtitle: '${profile.email} · ${profile.phone}',
                  onTap: () => _showChangePasswordDialog(context, ref),
                ),
              ),

              const SizedBox(height: 16),


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
                            // Unwind any pushed settings/sub-pages first.
                            // Logging out only swaps the route GoRouter owns
                            // underneath; a page pushed imperatively on top
                            // of it stays there, so the user would be left
                            // staring at a settings screen for an account
                            // they are no longer signed in to.
                            Navigator.of(context).popUntil((r) => r.isFirst);
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
                decoration: appDialogFieldDecoration(label: 'Requested Discount (Rs.) *', hint: 'e.g. 200', icon: PhosphorIconsRegular.currencyInr),
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32 + LiquidNavBar.barInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title removed: the page this sits in already names it, so
                // this row is just the "New Request" action.
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
