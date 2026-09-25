import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../data/app_data_provider.dart';
import '../auth/auth_provider.dart';
import 'widgets/owner_dashboard_tab.dart';
import 'widgets/owner_customers_employees_tab.dart';
import 'widgets/owner_billing_inventory_expenses_tab.dart';
import 'widgets/owner_management_tabs.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_page_switcher.dart';
import '../../widgets/app_settings_page.dart';
import '../../widgets/app_sub_page.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/liquid_nav_bar.dart';

const double kOwnerMobileBreakpoint = 900;

// The signed-in owner's own initials for their avatar badge - this used to
// be hardcoded to 'TO' (right for the "Test Owner" demo account, wrong for
// every real owner), so anyone other than that one test account would see
// someone else's initials on their own account.
String _ownerInitials(String? name) {
  final initials = (name ?? '').split(' ').where((n) => n.isNotEmpty).map((n) => n[0].toUpperCase()).take(2).join();
  return initials.isEmpty ? 'OW' : initials;
}

/// The four places the owner actually works out of.
///
/// This used to be a flat list of twelve equally-ranked pages, four of which
/// were on the bottom bar and the rest behind a "More" grid - so a salon
/// owner had to remember which of twelve screens owned a given task, and
/// the bar gave no hint which four mattered. Everything that isn't one of
/// these four is either a section of one of their settings screens (tax and
/// pricing under Billing, attendance under Team) or a destination in the
/// drawer, which is where the once-a-month work lives.
enum OwnerTab { dashboard, billing, clients, team }

class OwnerDashboard extends ConsumerStatefulWidget {
  const OwnerDashboard({super.key});

  @override
  ConsumerState<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends ConsumerState<OwnerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OwnerTab _activeTab = OwnerTab.dashboard;
  String? _preselectedCustomerId;
  // null = the whole salon; set from _showBranchSelector.
  String? _selectedBranchId;
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

  void _switchToTab(OwnerTab tab) {
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

  int get _pendingDiscountCount =>
      ref.watch(appDataProvider).valueOrNull?.discountRequests.where((r) => r.status == 'PENDING').length ?? 0;

  // ─── Drawer ───────────────────────────────────────────────────────────

  /// The work that isn't daily.
  ///
  /// These are real destinations rather than settings, so they push as
  /// full pages with a back arrow. Anything that *configures* a section
  /// (the GST rate, the price list, salary rules) belongs inside that
  /// section's own settings screen instead - which is why Inventory is
  /// here as a place to manage stock, while the same catalog appears as a
  /// pricing section under Billing.
  Widget _buildDrawer(BuildContext context, {required bool isModal}) {
    final appData = ref.watch(appDataProvider).valueOrNull;
    final salonName = appData?.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final ownerName = ref.watch(authControllerProvider).name;
    final lowStockCount = appData?.inventory.where((p) => p.isLowStock).length ?? 0;

    void go(String title, String subtitle, Widget page) {
      if (isModal) Navigator.pop(context);
      openAppSubPage(context, title: title, subtitle: subtitle, child: page);
    }

    return AppDrawer(
      isModal: isModal,
      title: salonName,
      subtitle: 'Owner · ${ownerName ?? 'Account'}',
      avatarInitials: _ownerInitials(ownerName),
      onProfileTap: () {
        if (isModal) Navigator.pop(context);
        _showProfileMenu(context, salonName);
      },
      onLogout: () {
        if (isModal) Navigator.pop(context);
        ref.read(authControllerProvider.notifier).logout();
      },
      sections: [
        AppDrawerSection(
          title: 'Go to',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.squaresFour,
              label: 'Dashboard',
              selected: _activeTab == OwnerTab.dashboard,
              onTap: () {
                if (isModal) Navigator.pop(context);
                _switchToTab(OwnerTab.dashboard);
              },
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.receipt,
              label: 'Billing',
              selected: _activeTab == OwnerTab.billing,
              onTap: () {
                if (isModal) Navigator.pop(context);
                _switchToTab(OwnerTab.billing);
              },
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.usersThree,
              label: 'Clients',
              selected: _activeTab == OwnerTab.clients,
              onTap: () {
                if (isModal) Navigator.pop(context);
                _switchToTab(OwnerTab.clients);
              },
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.identificationBadge,
              label: 'Team',
              selected: _activeTab == OwnerTab.team,
              onTap: () {
                if (isModal) Navigator.pop(context);
                _switchToTab(OwnerTab.team);
              },
            ),
          ],
        ),
        AppDrawerSection(
          title: 'Operations',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.package,
              label: 'Inventory',
              badgeCount: lowStockCount,
              onTap: () => go('Inventory', 'Stock, services and prices', const OwnerInventoryTab()),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.wallet,
              label: 'Expenses',
              onTap: () => go('Expenses', 'Petty cash and operational spend', const OwnerExpensesTab()),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.chartLineUp,
              label: 'Reports',
              onTap: () => go('Reports', 'Revenue, retention and staff performance', const OwnerReportsTab()),
            ),
          ],
        ),
        AppDrawerSection(
          title: 'Salon',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.gearSix,
              label: 'Salon Settings',
              onTap: () {
                if (isModal) Navigator.pop(context);
                _openSalonSettings(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Salon-level configuration, opened from Home's gear and from the
  /// drawer - one definition, so the two entry points can't drift into
  /// showing different things.
  void _openSalonSettings(BuildContext context) {
    final branches = ref.read(appDataProvider).valueOrNull?.branches ?? [];

    openAppSettings(
      context,
      title: 'Salon Settings',
      subtitle: 'How this salon is set up',
      sections: [
        AppSettingsSection(
          icon: PhosphorIconsRegular.storefront,
          label: 'Business',
          description: 'Name, phone and address. These appear on bills and receipts.',
          builder: (_) => const OwnerSettingsTab(),
        ),
        AppSettingsSection(
          icon: PhosphorIconsRegular.buildings,
          label: 'Branches',
          description: branches.length > 1
              ? '${branches.length} branches. Staff and bills are each tied to one.'
              : 'One location. Add a branch to track takings separately.',
          builder: (_) => const OwnerBranchTab(),
        ),
      ],
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────

  /// Five slots, five real destinations.
  ///
  /// The protruding "+" used to occupy the middle slot and opened a "Quick
  /// Actions" sheet whose four tiles only jumped to pages the bar already
  /// reached - a second navigation system layered over the first. Dropping
  /// it frees the slot for Team and makes the bar mean one thing.
  Widget _buildNavBar(BuildContext context) {
    return LiquidNavBar(
      selectedIndex: _activeTab.index,
      items: [
        LiquidNavItem(
          icon: PhosphorIconsRegular.squaresFour,
          activeIcon: PhosphorIconsFill.squaresFour,
          label: 'Home',
          onTap: () => _switchToTab(OwnerTab.dashboard),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.receipt,
          activeIcon: PhosphorIconsFill.receipt,
          label: 'Billing',
          onTap: () => _switchToTab(OwnerTab.billing),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.usersThree,
          activeIcon: PhosphorIconsFill.usersThree,
          label: 'Clients',
          onTap: () => _switchToTab(OwnerTab.clients),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.identificationBadge,
          activeIcon: PhosphorIconsFill.identificationBadge,
          label: 'Team',
          onTap: () => _switchToTab(OwnerTab.team),
        ),
        LiquidNavItem(
          icon: PhosphorIconsRegular.list,
          activeIcon: PhosphorIconsFill.list,
          label: 'Menu',
          badgeCount: _pendingDiscountCount,
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ],
    );
  }

  // ─── Sheets ───────────────────────────────────────────────────────────

  // Which branch the dashboard header is pointed at; null means the whole
  // salon. This sheet used to draw a checkmark on *every* row and discard
  // the tap, so it looked like a branch picker while selecting nothing - the
  // header then always showed branches.first regardless of what you chose.
  void _showBranchSelector(BuildContext context, List<dynamic> branches) {
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
                const Text(
                  'Select Branch',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                  ),
                ),
                const SizedBox(height: 12),
                if (branches.isEmpty)
                  ListTile(
                    leading: const Icon(PhosphorIconsFill.mapPin, color: AppTheme.primaryBlue),
                    title: const Text('Main Branch', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('No branches set up yet - add one from the menu'),
                    trailing: const Icon(PhosphorIconsBold.check, color: AppTheme.primaryBlue),
                    onTap: () => Navigator.pop(ctx),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(PhosphorIconsFill.buildings, color: AppTheme.primaryBlue),
                    title: const Text('All Branches', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Salon-wide totals'),
                    trailing: _selectedBranchId == null
                        ? const Icon(PhosphorIconsBold.check, color: AppTheme.primaryBlue)
                        : null,
                    onTap: () {
                      setState(() => _selectedBranchId = null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final b in branches)
                    ListTile(
                      leading: const Icon(PhosphorIconsFill.mapPin, color: AppTheme.primaryBlue),
                      title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(b.address?.isNotEmpty == true
                          ? b.address
                          : (b.active ? 'Active branch' : 'Deactivated')),
                      trailing: _selectedBranchId == b.id
                          ? const Icon(PhosphorIconsBold.check, color: AppTheme.primaryBlue)
                          : null,
                      onTap: () {
                        setState(() => _selectedBranchId = b.id);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfileMenu(BuildContext context, String salonName) {
    final ownerName = ref.read(authControllerProvider).name;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1B4B),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _ownerInitials(ownerName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  salonName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.slateDark,
                  ),
                ),
                const Text(
                  'Owner Account',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slateLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(authControllerProvider.notifier).logout();
                    },
                    icon: const Icon(PhosphorIconsRegular.signOut, color: AppTheme.accentRed),
                    label: const Text('Log Out', style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECDCA)),
                      backgroundColor: AppTheme.accentRedBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The bell, wired the same way from every page.
  void _openNotifications(BuildContext context) {
    if (_pendingDiscountCount > 0) {
      openAppSubPage(
        context,
        title: 'Discount Requests',
        subtitle: 'Staff requests waiting on you',
        child: const OwnerDiscountsTab(),
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

  // ─── Shell ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kOwnerMobileBreakpoint;

    final appData = ref.watch(appDataProvider).valueOrNull;
    final salonName = appData?.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final branches = appData?.branches ?? [];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.bgSurface,
      extendBody: isMobile,
      drawer: isMobile ? _buildDrawer(context, isModal: true) : null,
      bottomNavigationBar: isMobile ? _buildNavBar(context) : null,
      body: SafeArea(
        bottom: !isMobile,
        child: isMobile
            ? PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _activeTab = OwnerTab.values[index]);
                },
                children: _buildPages(context, salonName, branches),
              )
            : Row(
                children: [
                  _buildDrawer(context, isModal: false),
                  Expanded(
                    child: AppPageSwitcher(
                      child: _buildPages(context, salonName, branches)[_activeTab.index],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context, String salonName, List<dynamic> branches) {
    return [
      OwnerDashboardTab(
        key: const ValueKey('dashboard'),
        onOpenBilling: () => _switchToTab(OwnerTab.billing),
        // Attendance is a section of Team's settings, but it's also a daily
        // job, so Home keeps a one-tap route straight into it rather than
        // making the owner go Team -> gear -> Attendance every morning.
        onOpenAttendance: () => openAppSubPage(
          context,
          title: 'Attendance',
          subtitle: 'Today\'s clock-ins and shifts',
          child: const OwnerAttendanceTab(),
        ),
        onOpenNotifications: () => _openNotifications(context),
        onOpenProfile: () => _showProfileMenu(context, salonName),
        onOpenSettings: () => _openSalonSettings(context),
        onSelectBranch: () => _showBranchSelector(context, branches),
        // Drop the selection if that branch has since disappeared, so the
        // header can't keep pointing at a branch that no longer loads.
        selectedBranchId:
            branches.any((b) => b.id == _selectedBranchId) ? _selectedBranchId : null,
      ),
      OwnerBillingTab(
        key: const ValueKey('billing'),
        preselectedCustomerId: _preselectedCustomerId,
      ),
      OwnerCustomersTab(
        key: const ValueKey('clients'),
        onStartBill: (customer) {
          setState(() => _preselectedCustomerId = customer.id);
          _switchToTab(OwnerTab.billing);
        },
        onOpenNotifications: () => _openNotifications(context),
      ),
      OwnerEmployeesTab(
        key: const ValueKey('team'),
        onOpenNotifications: () => _openNotifications(context),
      ),
    ];
  }
}


// --- REPORTS TAB ---

const List<String> _kMonthAbbrevs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class OwnerReportsTab extends ConsumerStatefulWidget {
  final VoidCallback? onOpenNotifications;

  const OwnerReportsTab({super.key, this.onOpenNotifications});

  @override
  ConsumerState<OwnerReportsTab> createState() => _OwnerReportsTabState();
}

class _OwnerReportsTabState extends ConsumerState<OwnerReportsTab> {
  String _activeSegment = 'Overview';
  String _timeframe = 'Last 6 Months';

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      data: (state) => _buildContent(context, state),
    );
  }

  Widget _buildContent(BuildContext context, AppData state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Cuts Salon';
        // Reports are always salon-wide, so naming one branch here (it used
        // to print branches.first) read as a scope that was never applied.
        final branchName = state.branches.length > 1
            ? 'All Branches'
            : (state.branches.isNotEmpty ? state.branches.first.name : 'Main Branch');
        final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING').length;

        final now = DateTime.now();
        final months = List.generate(6, (i) {
          final monthIndex = now.month - (5 - i);
          final yearOffset = ((monthIndex - 1) / 12).floor();
          final normalizedMonth = ((monthIndex - 1) % 12 + 12) % 12 + 1;
          return DateTime(now.year + yearOffset, normalizedMonth, 1);
        });

        final revenueByMonth = months
            .map((m) => state.bills
                .where((b) => b.createdAt != null && b.createdAt!.year == m.year && b.createdAt!.month == m.month)
                .fold<double>(0, (s, b) => s + b.finalAmount))
            .toList();
        final monthLabels = months.map((m) => _kMonthAbbrevs[m.month - 1]).toList();

        // Real data only below - this screen used to fall back to hardcoded
        // demo numbers (fake revenue, fake bill counts, fake categories) when
        // a salon had little/no history yet, which would show a real owner
        // fabricated business figures as if they were their own. Every
        // metric here must come from state, or show an honest empty state.
        final List<double> chartValues = revenueByMonth;

        final totalRevenue = state.bills.fold<double>(0, (s, b) => s + b.finalAmount);
        final totalBillsCount = state.bills.length;
        final atv = totalBillsCount > 0 ? (totalRevenue / totalBillsCount) : 0.0;

        final billsByCustomer = <String, int>{};
        for (final b in state.bills) {
          billsByCustomer[b.customerId] = (billsByCustomer[b.customerId] ?? 0) + 1;
        }
        final customersWithBills = billsByCustomer.length;
        final repeatCustomers = billsByCustomer.values.where((c) => c > 1).length;
        final retentionPct = customersWithBills > 0 ? ((repeatCustomers / customersWithBills) * 100).toInt() : 0;

        final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
        final presentCount = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
        final attendanceRate = monthAttendance.isNotEmpty ? ((presentCount / monthAttendance.length) * 100).toInt() : 0;

        // Categories popularity
        final categoryVolume = <String, int>{};
        for (final bill in state.bills) {
          for (final item in bill.items) {
            if (item.type != 'SERVICE') continue;
            final matches = state.services.where((s) => s.id == item.serviceId);
            final categoryName = matches.isNotEmpty ? (matches.first.categoryName ?? 'Uncategorized') : 'Uncategorized';
            categoryVolume[categoryName] = (categoryVolume[categoryName] ?? 0) + item.quantity;
          }
        }

        final sortedCategories = categoryVolume.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topCategories = sortedCategories.take(5).toList();

        final latestMonthRevenue = chartValues.isNotEmpty ? chartValues.last : 0.0;
        final latestMonthName = monthLabels.isNotEmpty ? monthLabels.last : '';

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 16.0 : 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pinned Salon Header
              _buildReportSalonHeader(context, salonName, branchName, pendingDiscountCount),
              const SizedBox(height: 16),

              // 2. Title & Timeframe Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Analytical Reports',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Business performance & revenue insights',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _showTimeframePicker(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeframe.contains('6') ? 'Last 6' : _timeframe.contains('3') ? 'Last 3' : 'Current',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                              const Text(
                                'Months',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsBold.caretDown, size: 10, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Segmented Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildReportSegmentPill('Overview'),
                    const SizedBox(width: 8),
                    _buildReportSegmentPill('Revenue'),
                    const SizedBox(width: 8),
                    _buildReportSegmentPill('Services'),
                    const SizedBox(width: 8),
                    _buildReportSegmentPill('Staff Performance'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Revenue Trend Card
              _buildRevenueTrendCard(
                totalRevenue: totalRevenue,
                chartValues: chartValues,
                monthLabels: monthLabels,
                latestMonthRevenue: latestMonthRevenue,
                latestMonthName: latestMonthName,
              ),
              const SizedBox(height: 14),

              // 5. Service Popularity (Top 5) Card
              _buildServicePopularityCard(topCategories: topCategories),
              const SizedBox(height: 14),

              // 6. Key Metrics Row (3 cards side by side)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTileCompact(
                      icon: PhosphorIconsRegular.receipt,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF6366F1),
                      title: 'Avg Ticket',
                      value: '₹${atv.toStringAsFixed(0)}',
                      subtext: 'Across $totalBillsCount bill${totalBillsCount == 1 ? '' : 's'}',
                      subtextColor: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTileCompact(
                      icon: PhosphorIconsRegular.usersThree,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF10B981),
                      title: 'Retention',
                      value: '$retentionPct%',
                      subtext: '$repeatCustomers of $customersWithBills returned',
                      subtextColor: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTileCompact(
                      icon: PhosphorIconsRegular.shieldCheck,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF3B82F6),
                      title: 'Attendance',
                      value: '$attendanceRate%',
                      subtext: 'This month, all staff',
                      subtextColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 7. Export Detailed Audit Bar
              _buildExportAuditBar(context),

              const SizedBox(height: 88), // floating navbar clearance
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportSalonHeader(BuildContext context, String salonName, String branchName, int unreadCount) {
    final ownerName = ref.watch(authControllerProvider).name;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                salonName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      branchName,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
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
            color: Color(0xFF1E1B4B),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _ownerInitials(ownerName),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSegmentPill(String title) {
    final isSelected = _activeSegment == title;
    return InkWell(
      onTap: () => setState(() => _activeSegment = title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475467),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueTrendCard({
    required double totalRevenue,
    required List<double> chartValues,
    required List<String> monthLabels,
    required double latestMonthRevenue,
    required String latestMonthName,
  }) {
    // Real month-over-month change, not a fabricated placeholder - only
    // shown when the prior month actually has revenue to compare against,
    // since a % change against zero is undefined, not "+something".
    final hasPriorMonth = chartValues.length >= 2 && chartValues[chartValues.length - 2] > 0;
    final momPct = hasPriorMonth
        ? ((chartValues.last - chartValues[chartValues.length - 2]) / chartValues[chartValues.length - 2]) * 100
        : 0.0;
    final momIsUp = momPct >= 0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Revenue\nTrend',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                      if (hasPriorMonth) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: momIsUp ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                momIsUp ? PhosphorIconsBold.arrowUpRight : PhosphorIconsBold.arrowDownRight,
                                size: 10,
                                color: momIsUp ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${momIsUp ? '+' : ''}${momPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: momIsUp ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Monthly salon turnover',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                '₹${totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Custom Smooth Curved Line Chart
          SizedBox(
            height: 155,
            width: double.infinity,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, 155),
                  painter: _ReportsRevenueCurvePainter(
                    values: chartValues,
                    labels: monthLabels,
                  ),
                ),
                // Tooltip indicator badge on top right of the curve
                Positioned(
                  right: 10,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '₹${latestMonthRevenue.toStringAsFixed(0)} ($latestMonthName)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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
  }

  Widget _buildServicePopularityCard({required List<MapEntry<String, int>> topCategories}) {
    final maxVal = topCategories.isEmpty ? 1 : topCategories.map((e) => e.value).reduce((a, b) => a > b ? a : b);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Service Popularity',
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
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Top 5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
              const Icon(PhosphorIconsRegular.slidersHorizontal, size: 18, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Volume by service category',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),

          // 5 Vertical Rounded Bars
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: topCategories.map((cat) {
                final heightFraction = (cat.value / maxVal).clamp(0.18, 1.0);
                final barHeight = 88.0 * heightFraction;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${cat.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: barHeight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.key,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTileCompact({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required String subtext,
    required Color subtextColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: subtextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildExportAuditBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              PhosphorIconsRegular.downloadSimple,
              color: Color(0xFF6366F1),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Export Detailed Audit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PDF & CSV formats ready',
                  style: TextStyle(
                    fontSize: 11,
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
                const SnackBar(
                  content: Text('Preparing detailed audit export (PDF/CSV)...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Share',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeframePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Timeframe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Last 6 Months', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Last 6 Months' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF4F46E5)) : null,
                  onTap: () {
                    setState(() => _timeframe = 'Last 6 Months');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Last 3 Months', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Last 3 Months' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF4F46E5)) : null,
                  onTap: () {
                    setState(() => _timeframe = 'Last 3 Months');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Current Year', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Current Year' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF4F46E5)) : null,
                  onTap: () {
                    setState(() => _timeframe = 'Current Year');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportsRevenueCurvePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  _ReportsRevenueCurvePainter({
    required this.values,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) <= 0 ? 1.0 : (maxVal - minVal);

    const double paddingBottom = 24.0;
    const double paddingTop = 28.0;
    final double chartHeight = size.height - paddingBottom - paddingTop;
    final double stepX = size.width / (values.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalized = (values[i] - minVal) / range;
      final y = size.height - paddingBottom - (normalized * chartHeight);
      points.add(Offset(x, y));
    }

    // Gradient fill path
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height - paddingBottom);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      fillPath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height - paddingBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.28),
          const Color(0xFF6366F1).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke path
    final strokePath = Path();
    strokePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      strokePath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(strokePath, strokePaint);

    // Draw dots and text
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, 4.5, dotPaint);
      canvas.drawCircle(p, 4.5, dotBorderPaint);

      // Label below
      final textSpan = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: i == points.length - 1 ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
          fontSize: 10.5,
          fontWeight: i == points.length - 1 ? FontWeight.w800 : FontWeight.w600,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(p.dx - (tp.width / 2), size.height - paddingBottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

