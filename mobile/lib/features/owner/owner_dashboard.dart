import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../data/app_data_provider.dart';
import '../auth/auth_provider.dart';
import 'widgets/owner_dashboard_tab.dart';
import 'widgets/client_retention_report.dart';
import 'widgets/payment_method_report.dart';
import 'widgets/owner_customers_employees_tab.dart';
import 'widgets/owner_billing_inventory_expenses_tab.dart';
import 'widgets/owner_management_tabs.dart';
import 'widgets/owner_payment_requests_view.dart';
import 'widgets/owner_profile_view.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_page_header.dart' show AppPageAction;
import '../../widgets/dues_view.dart';
import '../../widgets/app_page_switcher.dart';
import '../../widgets/app_settings_page.dart';
import '../../widgets/app_sub_page.dart';
import '../../widgets/async_state_views.dart';
import '../../widgets/csv_export.dart';
import '../../data/models.dart';
import '../../widgets/liquid_nav_bar.dart';
import '../../data/money.dart';
import '../../widgets/pull_to_refresh.dart';

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

  // ─── Drawer ───────────────────────────────────────────────────────────

  /// The work that isn't daily.
  ///
  /// These are real destinations rather than settings, so they push as
  /// full pages with a back arrow. Anything that *configures* a section
  /// (the GST rate, the price list, salary rules) belongs inside that
  /// section's own settings screen instead - which is why Inventory is
  /// here as a place to manage stock, while the same catalog appears as a
  /// pricing section under Billing.
  /// Services, with "Add" (service or product) in its header. Opened from
  /// the drawer and from Home's setup checklist.
  void _openServices(BuildContext context) {
    openAppSubPage(
      context,
      title: 'Services',
      subtitle: 'Service menu, stock and prices',
      actions: [
        AppPageAction(
          icon: PhosphorIconsBold.plus,
          label: 'Add',
          tooltip: 'Add a service or product',
          onTap: () => showAddCatalogItemSheet(context, ref),
        ),
      ],
      child: const OwnerInventoryTab(),
    );
  }

  Widget _buildDrawer(BuildContext context, {required bool isModal}) {
    final appData = ref.watch(appDataProvider).valueOrNull;
    final salonName = appData?.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final ownerName = ref.watch(authControllerProvider).name;
    final lowStockCount = appData?.inventory.where((p) => p.isLowStock).length ?? 0;

    void go(String title, String subtitle, Widget page, {List<AppPageAction> actions = const []}) {
      if (isModal) Navigator.pop(context);
      openAppSubPage(context, title: title, subtitle: subtitle, actions: actions, child: page);
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
        // The four tabs only in the desktop sidebar: on a phone the bottom
        // bar already shows them, and repeating them at the top of the menu
        // pushed what the menu is actually for below the fold.
        if (!isModal)
        AppDrawerSection(
          title: 'Go to',
          items: [
            AppDrawerItem(
              icon: PhosphorIconsRegular.squaresFour,
              label: 'Home',
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
            // First in Operations because it is the first thing done each
            // day. It was reachable only from Home's quick action and from
            // Team -> gear -> Attendance, neither of which is where someone
            // looks for a daily job - and the owner's own shift lives at the
            // top of this screen, so they had no obvious route to their own
            // clock-in at all.
            AppDrawerItem(
              icon: PhosphorIconsRegular.calendarCheck,
              label: 'Attendance',
              onTap: () => go('Attendance', "Your shift, and today's roster", const OwnerAttendanceTab()),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.package,
              label: 'Services',
              badgeCount: lowStockCount,
              onTap: () {
                if (isModal) Navigator.pop(context);
                _openServices(context);
              },
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.wallet,
              label: 'Expenses',
              onTap: () => go(
                'Expenses',
                'Rent, bills and other costs',
                const OwnerExpensesTab(),
                actions: [
                  AppPageAction(
                    icon: PhosphorIconsBold.plus,
                    label: 'Add',
                    tooltip: 'Add expense',
                    onTap: () => showAddExpenseDialog(context, ref),
                  ),
                ],
              ),
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
          description: 'Name, phone and address for bills, GST, late penalty and WhatsApp messages.',
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
          // No badge: the bell carries what's waiting on the owner.
          // Scaffold.of(context), not a GlobalKey - see the employee
          // dashboard's note: the key's currentState reads null if the
          // Scaffold remounts, and the button then silently does nothing.
          onTap: () => Scaffold.of(context).openEndDrawer(),
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
                    fontWeight: FontWeight.w700,
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

  /// The owner's own profile.
  ///
  /// This used to be a bottom sheet holding an avatar, the salon name, the
  /// words "Owner Account" and a log-out button - none of it the owner's own
  /// details, so tapping the account row in the drawer looked like it had
  /// failed to open anything. It now opens the same sub-page shell every
  /// other destination uses, filled from the employees/{uid} record already
  /// in the loaded snapshot (no extra read) with the auth session as the
  /// fallback for a salon whose owner has no employee document yet.
  void _showProfileMenu(BuildContext context, String salonName) {
    openAppSubPage(
      context,
      title: 'My Profile',
      subtitle: salonName,
      child: const OwnerProfileView(),
    );
  }

  /// The bell: payments staff collected from clients, waiting for the
  /// owner to confirm. (Discount requests used to share this inbox; they
  /// went with staff billing, since an approved discount only ever applied
  /// to a bill a stylist made.)
  void _openNotifications(BuildContext context) {
    final payments = ref.read(appDataProvider).valueOrNull?.pendingPaymentRequestCount ?? 0;
    openAppSubPage(
      context,
      title: 'Requests',
      subtitle: payments > 0
          ? '$payments payment${payments == 1 ? '' : 's'} waiting for you to confirm'
          : 'Nothing waiting on you',
      child: const OwnerPaymentRequestsView(),
    );
  }

  // ─── Shell ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kOwnerMobileBreakpoint;

    final appData = ref.watch(appDataProvider).valueOrNull;
    final salonName = appData?.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final branches = appData?.branches ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      extendBody: isMobile,
      // endDrawer: the Menu button is the last slot on the bottom bar, at the
      // right edge, so the panel slides in from that side - it used to come
      // from the left, the opposite side from where the thumb just tapped.
      endDrawer: isMobile ? _buildDrawer(context, isModal: true) : null,
      bottomNavigationBar: isMobile ? Builder(builder: _buildNavBar) : null,
      body: SafeArea(
        bottom: !isMobile,
        child: isMobile
            // No bottom padding here on purpose: the page is meant to run
            // under the glass bar and be visible through it. Each tab's own
            // scrollable carries LiquidNavBar.barInset instead, so content
            // passes beneath the capsule while scrolling but the last row
            // still comes to rest clear of it.
            ? PageView(
                controller: _pageController,
                // Tabs change from the bar only. Swiping the page sideways
                // used to flip to the next tab, which fired by accident while
                // scrolling the horizontal filter-chip rows on every list.
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _activeTab = OwnerTab.values[index]);
                },
                // Each tab can be pulled down to reload (PullToRefresh).
                children: [
                  for (final page in _buildPages(context, salonName, branches))
                    PullToRefresh(key: page.key, child: page),
                ],
              )
            : Row(
                children: [
                  _buildDrawer(context, isModal: false),
                  Expanded(
                    child: AppPageSwitcher(
                      child: Builder(builder: (context) {
                        final page = _buildPages(context, salonName, branches)[_activeTab.index];
                        return PullToRefresh(key: page.key, child: page);
                      }),
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
        onOpenClients: () => _switchToTab(OwnerTab.clients),
        onOpenServices: () => _openServices(context),
        onOpenTeam: () => _switchToTab(OwnerTab.team),
        onOpenDues: () => openAppSubPage(
          context,
          title: 'Dues',
          subtitle: 'What clients still owe, by client',
          child: const DuesView(),
        ),
        onOpenReports: () => openAppSubPage(
          context,
          title: 'Reports',
          subtitle: 'Revenue, retention and staff performance',
          child: const OwnerReportsTab(),
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
        onOpenNotifications: () => _openNotifications(context),
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
  // Staff tab's month: 0 = this month, 1 = last month, ...
  int _staffMonthsBack = 0;
  /// null = every branch. Reports were salon-wide with no way to narrow them.
  String? _branchId;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      data: (state) => _buildContent(context, state),
    );
  }

  /// How far back the figures on this page go. The picker used to set a
  /// label and nothing else - every number below was hardcoded to the last
  /// six months whatever it said, so "Current Year" was a lie the UI told.
  int get _monthsBack => switch (_timeframe) {
        'Last 3 Months' => 3,
        'Current Year' => DateTime.now().month,
        _ => 6,
      };

  /// Bills in scope: the chosen branch, over the chosen window. Everything on
  /// this page derives from this one list, so the branch pill and the
  /// timeframe pill cannot disagree with each other.
  List<Bill> _scopedBills(AppData state, DateTime from) => state.bills
      .where((b) =>
          b.createdAt != null &&
          !b.createdAt!.isBefore(from) &&
          (_branchId == null || b.branchId == _branchId))
      .toList();

  Widget _buildContent(BuildContext context, AppData state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        // Reports used to be salon-wide with no way to narrow them, so an
        // owner running three branches could not answer "how did Vijay Nagar
        // do" from this page at all.
        final selectedBranch = state.branches.where((b) => b.id == _branchId);
        final branchName = selectedBranch.isNotEmpty
            ? selectedBranch.first.name
            : (state.branches.length > 1
                ? 'All branches'
                : (state.branches.isNotEmpty ? state.branches.first.name : 'Main Branch'));

        final now = DateTime.now();
        final months = List.generate(_monthsBack, (i) {
          final monthIndex = now.month - (_monthsBack - 1 - i);
          final yearOffset = ((monthIndex - 1) / 12).floor();
          final normalizedMonth = ((monthIndex - 1) % 12 + 12) % 12 + 1;
          return DateTime(now.year + yearOffset, normalizedMonth, 1);
        });
        final windowStart = months.first;
        final bills = _scopedBills(state, windowStart);

        final revenueByMonth = months
            .map((m) => bills
                .where((b) => b.createdAt!.year == m.year && b.createdAt!.month == m.month)
                .fold<double>(0, (s, b) => s + b.finalAmount))
            .toList();
        final monthLabels = months.map((m) => _kMonthAbbrevs[m.month - 1]).toList();

        // Real data only below - this screen used to fall back to hardcoded
        // demo numbers (fake revenue, fake bill counts, fake categories) when
        // a salon had little/no history yet, which would show a real owner
        // fabricated business figures as if they were their own. Every
        // metric here must come from state, or show an honest empty state.
        final List<double> chartValues = revenueByMonth;

        final totalRevenue = bills.fold<double>(0, (s, b) => s + b.finalAmount);
        final totalBillsCount = bills.length;
        final atv = totalBillsCount > 0 ? (totalRevenue / totalBillsCount) : 0.0;

        final billsByCustomer = <String, int>{};
        for (final b in bills) {
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
        for (final bill in bills) {
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
              // (A salon-name + owner-avatar strip used to sit here. The owner
              // knows which salon this is; with several branches the branch
              // pill below says which one.)
              // 2. Title & Timeframe Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // No second "Analytical Reports" heading here: this page
                  // always opens under the "Reports" page header, and the
                  // two titles stacked read as a layout glitch.
                  const Expanded(
                    child: Text(
                      'Period',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showTimeframePicker(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: Color(0xFF1E3A5F)),
                          const SizedBox(width: 6),
                          // One line - it was split over two tiny lines
                          // ("Last 6" / "Months").
                          Text(
                            _timeframe.contains('6')
                                ? 'Last 6 months'
                                : _timeframe.contains('3')
                                    ? 'Last 3 months'
                                    : 'This year',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(PhosphorIconsBold.caretDown, size: 10, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2b. Branch scope. Same pill Home and Team use.
              if (state.branches.length > 1) ...[
                _buildReportBranchPill(state, branchName, bills.length),
                const SizedBox(height: 14),
              ],

              // 3. Segmented Tabs. These used to set _activeSegment and
              // nothing read it, so every tab showed the same four cards.
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
                    _buildReportSegmentPill('Staff'),
                    const SizedBox(width: 8),
                    _buildReportSegmentPill('Clients'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_activeSegment == 'Overview') ...[
                _buildRevenueTrendCard(
                  totalRevenue: totalRevenue,
                  chartValues: chartValues,
                  monthLabels: monthLabels,
                  latestMonthRevenue: latestMonthRevenue,
                  latestMonthName: latestMonthName,
                ),
                const SizedBox(height: 14),
                _buildServicePopularityCard(topCategories: topCategories),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTileCompact(
                        icon: PhosphorIconsRegular.receipt,
                        iconBg: const Color(0xFFDCE4EF),
                        iconColor: const Color(0xFF2F4E79),
                        title: 'Avg bill',
                        value: formatInr(atv),
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
                        iconBg: const Color(0xFFF1F4F8),
                        iconColor: const Color(0xFF3E5F8A),
                        title: 'Attendance',
                        value: '$attendanceRate%',
                        subtext: 'This month',
                        subtextColor: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ] else if (_activeSegment == 'Revenue') ...[
                _buildRevenueTrendCard(
                  totalRevenue: totalRevenue,
                  chartValues: chartValues,
                  monthLabels: monthLabels,
                  latestMonthRevenue: latestMonthRevenue,
                  latestMonthName: latestMonthName,
                ),
                const SizedBox(height: 14),
                // Replaces a bar list that labelled its rows with the raw
                // stored values - CASH, UPI, PENDING - drew every bar the
                // same colour, and dropped a method entirely when it had no
                // bills, so "no card takings this month" and "card is not a
                // thing here" looked identical.
                PaymentMethodReport(
                  bills: bills,
                  formatCurrency: _formatReportCurrency,
                ),
              ] else if (_activeSegment == 'Services') ...[
                _buildServicePopularityCard(topCategories: topCategories),
                const SizedBox(height: 14),
                _buildTopServicesCard(state, bills),
              ] else if (_activeSegment == 'Staff') ...[
                _buildStaffMonthlyCard(state),
                const SizedBox(height: 14),
                _buildStaffPerformanceCard(state, bills),
              ] else ...[
                // Retention comes off the customer documents, not off the
                // bills list: that list is capped, so counting visits from it
                // would undercount anyone whose visits fell outside the
                // window that happened to be loaded. visitCount and
                // lastVisitAt are denormalized by every bill, so they are
                // complete - and already in this snapshot, costing no read.
                //
                // The flip side is that these are lifetime figures and do not
                // narrow with the timeframe pill above. The cards say so.
                ClientRetentionReport(
                  customers: state.customers,
                  now: DateTime.now(),
                ),
              ],
              const SizedBox(height: 14),

              // 7. Export Detailed Audit Bar
              _buildExportAuditBar(context, state, bills, windowStart),

              const SizedBox(height: 88), // floating navbar clearance
            ],
          ),
        );
      },
    );
  }

  /// Branch scope for this page. Deliberately the same control as Home's and
  /// Team's, so the pill means one thing everywhere in the app.
  Widget _buildReportBranchPill(AppData state, String label, int billCount) {
    return InkWell(
      onTap: () => _showReportBranchPicker(state),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.mapPin, size: 14, color: Color(0xFF1E3A5F)),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 6),
            Text(
              '$billCount bill${billCount == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 5),
            const Icon(PhosphorIconsBold.caretDown, size: 11, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _showReportBranchPicker(AppData state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget option(String label, String? branchId) {
          final isSelected = _branchId == branchId;
          return ListTile(
            leading: Icon(
              branchId == null ? PhosphorIconsRegular.buildings : PhosphorIconsRegular.storefront,
              size: 19,
              color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8),
            ),
            title: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            trailing: isSelected ? const Icon(PhosphorIconsBold.check, size: 17, color: Color(0xFF1E3A5F)) : null,
            onTap: () {
              setState(() => _branchId = branchId);
              Navigator.pop(ctx);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Report on',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              option('All branches', null),
              for (final b in state.branches) option(b.name, b.id),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// How the money actually arrived. Collected, not billed - a part-paid bill
  /// only contributes what was handed over, same rule the dashboard uses.
  /// Individual services rather than their categories - the popularity chart
  /// above answers "which kind of work", this answers "which item on the menu".
  Widget _buildTopServicesCard(AppData state, List<Bill> bills) {
    final revenueByService = <String, double>{};
    final countByService = <String, int>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.type != 'SERVICE') continue;
        final name = item.serviceName ?? 'Unnamed service';
        revenueByService[name] =
            (revenueByService[name] ?? 0) + (item.unitPrice * item.quantity - item.discountAmount);
        countByService[name] = (countByService[name] ?? 0) + item.quantity;
      }
    }
    final rows = revenueByService.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(8).toList();
    final maxVal = top.isEmpty ? 1.0 : top.first.value;

    return _reportCard(
      title: 'Top Services',
      subtitle: 'By revenue over this window',
      child: top.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No services billed in this window.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          : Column(
              children: [
                for (final e in top) ...[
                  _reportBarRow(
                    label: e.key,
                    value: '${formatInr(e.value)} · ${countByService[e.key]}×',
                    fraction: maxVal > 0 ? e.value / maxVal : 0,
                    color: const Color(0xFF2F4E79),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  /// Who brought the money in. Attributed per line item, because two stylists
  /// can share one bill - splitting by the bill's own total would credit all
  /// of it to whoever happened to be on the first line.
  /// Clients each person handled in one calendar month, with bills,
  /// services and takings beside it and the change from the month before.
  /// Everyone on the team is listed, including people with nothing that
  /// month - a missing row would hide exactly the person worth asking about.
  Widget _buildStaffMonthlyCard(AppData state) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - _staffMonthsBack, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final prev = DateTime(month.year, month.month - 1, 1);

    Iterable<Bill> between(DateTime from, DateTime to) => state.bills.where((b) =>
        b.createdAt != null &&
        !b.createdAt!.isBefore(from) &&
        b.createdAt!.isBefore(to) &&
        (_branchId == null || b.branchId == _branchId));

    final clients = <String, Set<String>>{};
    final billIds = <String, Set<String>>{};
    final services = <String, int>{};
    final takings = <String, double>{};
    for (final bill in between(month, next)) {
      for (final item in bill.items) {
        final id = item.employeeId;
        if (id.isEmpty) continue;
        (clients[id] ??= <String>{}).add(bill.customerId);
        (billIds[id] ??= <String>{}).add(bill.id);
        if (item.type == 'SERVICE') services[id] = (services[id] ?? 0) + item.quantity;
        takings[id] = (takings[id] ?? 0) + (item.unitPrice * item.quantity - item.discountAmount);
      }
    }
    final prevClients = <String, Set<String>>{};
    for (final bill in between(prev, month)) {
      for (final item in bill.items) {
        if (item.employeeId.isEmpty) continue;
        (prevClients[item.employeeId] ??= <String>{}).add(bill.customerId);
      }
    }

    final ids = <String>{
      ...state.employees
          .where((e) => _branchId == null || e.branchId.isEmpty || e.branchId == _branchId)
          .map((e) => e.id),
      ...clients.keys,
    }.toList()
      ..sort((a, b) {
        final byClients = (clients[b]?.length ?? 0).compareTo(clients[a]?.length ?? 0);
        return byClients != 0 ? byClients : (takings[b] ?? 0).compareTo(takings[a] ?? 0);
      });

    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthLabel = '${monthNames[month.month - 1]} ${month.year}';
    final prevLabel = _kMonthAbbrevs[prev.month - 1];

    Widget stepper(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          onPressed: onTap,
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFCBD5E1) : AppTheme.slateDark),
        );

    return _reportCard(
      title: 'Clients handled',
      subtitle: 'Per staff member, one month at a time',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                stepper(PhosphorIconsBold.caretLeft, 'Previous month',
                    _staffMonthsBack >= 11 ? null : () => setState(() => _staffMonthsBack++)),
                Expanded(
                  child: Text(
                    _staffMonthsBack == 0 ? '$monthLabel (so far)' : monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateDark),
                  ),
                ),
                stepper(PhosphorIconsBold.caretRight, 'Next month',
                    _staffMonthsBack == 0 ? null : () => setState(() => _staffMonthsBack--)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (ids.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No staff yet.', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
            )
          else
            for (var i = 0; i < ids.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppTheme.borderSubtle),
              _staffMonthRow(
                name: state.employeeById(ids[i])?.name ?? 'Former staff',
                clients: clients[ids[i]]?.length ?? 0,
                prevClients: prevClients[ids[i]]?.length ?? 0,
                prevLabel: prevLabel,
                bills: billIds[ids[i]]?.length ?? 0,
                services: services[ids[i]] ?? 0,
                takings: takings[ids[i]] ?? 0,
              ),
            ],
        ],
      ),
    );
  }

  Widget _staffMonthRow({
    required String name,
    required int clients,
    required int prevClients,
    required String prevLabel,
    required int bills,
    required int services,
    required double takings,
  }) {
    final (bg, fg) = AppTheme.avatarColorsFor(name);
    final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final delta = clients - prevClients;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bg,
            child: Text(initials, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                const SizedBox(height: 2),
                Text(
                  '$bills bill${bills == 1 ? '' : 's'} · $services service${services == 1 ? '' : 's'} · ${_formatReportCurrency(takings)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$clients',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
              ),
              Text(
                delta == 0
                    ? 'clients · same as $prevLabel'
                    : 'clients · ${delta > 0 ? '+' : ''}$delta vs $prevLabel',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: delta > 0
                      ? AppTheme.accentGreen
                      : delta < 0
                          ? AppTheme.accentRed
                          : AppTheme.slateLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard(AppData state, List<Bill> bills) {
    final revenueByEmployee = <String, double>{};
    final itemsByEmployee = <String, int>{};
    final billsByEmployee = <String, Set<String>>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.employeeId.isEmpty) continue;
        revenueByEmployee[item.employeeId] = (revenueByEmployee[item.employeeId] ?? 0) +
            (item.unitPrice * item.quantity - item.discountAmount);
        itemsByEmployee[item.employeeId] = (itemsByEmployee[item.employeeId] ?? 0) + item.quantity;
        (billsByEmployee[item.employeeId] ??= <String>{}).add(bill.id);
      }
    }
    final rows = revenueByEmployee.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = rows.isEmpty ? 1.0 : rows.first.value;

    return _reportCard(
      title: 'Takings by staff',
      subtitle: 'For the period above, from the services and products each person billed',
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No billed work in this window.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              ),
            )
          : Column(
              children: [
                for (final e in rows) ...[
                  _reportBarRow(
                    label: state.employeeById(e.key)?.name ?? 'Former staff',
                    value: '${formatInr(e.value)} · ${billsByEmployee[e.key]!.length} bill${billsByEmployee[e.key]!.length == 1 ? '' : 's'}',
                    fraction: maxVal > 0 ? e.value / maxVal : 0,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  /// The card chrome the three segment cards above share, so they cannot
  /// drift into three slightly different whites.
  Widget _reportCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// A labelled horizontal bar. Horizontal rather than vertical because the
  /// labels here are names ("Anjali Mehta", "Keratin Treatment") which do not
  /// fit under a 28px column.
  /// Indian digit grouping, the same shape the revenue headline on this page
  /// already uses. Lifted into a method so the payment card and that headline
  /// cannot drift into formatting the same rupee figure two ways.
  String _formatReportCurrency(double amount) {
    final whole = amount.round().toString();
    final grouped = whole.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '\u20B9$grouped';
  }

  Widget _reportBarRow({
    required String label,
    required String value,
    required double fraction,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 7,
            color: const Color(0xFFF1F5F9),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              // A zero-width bar reads as a rendering bug rather than as a
              // small number, so every row keeps a visible sliver.
              widthFactor: fraction.clamp(0.02, 1.0),
              child: Container(color: color),
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
          // Same light-tint chip as every other filter row in the app.
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFC3D0E2) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppTheme.primaryBlue : const Color(0xFF475467),
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
        boxShadow: AppTheme.cardShadow,
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
                        'Revenue trend',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
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
                                  fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Text(
                      '${formatInr(latestMonthRevenue)} ($latestMonthName)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
        boxShadow: AppTheme.cardShadow,
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
                    'Popular services',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE4EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Top 5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2F4E79),
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
            'Services done, by category',
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
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: barHeight,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E3A5F),
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
        boxShadow: AppTheme.cardShadow,
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
              fontWeight: FontWeight.w700,
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

  Widget _buildExportAuditBar(
    BuildContext context,
    AppData state,
    List<Bill> bills,
    DateTime windowStart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCE4EF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              PhosphorIconsRegular.downloadSimple,
              color: Color(0xFF2F4E79),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Download bills',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Spreadsheet (CSV), one row per item',
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
            onTap: () => _exportAudit(context, state, bills, windowStart),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Export',
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

  /// Builds the audit CSV from the bills already on screen and hands it over.
  ///
  /// One row per bill *line*, not per bill: the questions this export exists
  /// to answer (what did we sell, who performed it, what commission is owed)
  /// are all line-level, and a per-bill row would force whoever opens it in
  /// Excel to go back to the app for the breakdown. Everything comes from the
  /// loaded snapshot, so exporting costs no Firestore read at all.
  Future<void> _exportAudit(
    BuildContext context,
    AppData state,
    List<Bill> bills,
    DateTime windowStart,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final rows = <List<Object?>>[
      [
        'Invoice',
        'Date',
        'Branch',
        'Client',
        'Type',
        'Item',
        'Qty',
        'Unit price',
        'Line discount',
        'Line total',
        'Performed by',
        'Commission',
        'Bill total',
        'Paid',
        'Balance',
        'Payment method',
      ],
    ];

    final branchNames = {for (final b in state.branches) b.id: b.name};
    // Newest first, matching how every list in the app is ordered.
    final sorted = [...bills]
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

    for (final bill in sorted) {
      final date = bill.createdAt;
      final dateText = date == null
          ? ''
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (bill.items.isEmpty) {
        // A bill with no loaded lines still belongs in the audit - dropping
        // it would make the CSV's totals disagree with the app's.
        rows.add([
          bill.invoiceNumber,
          dateText,
          branchNames[bill.branchId] ?? bill.branchId,
          bill.customerName ?? '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          bill.finalAmount.toStringAsFixed(2),
          bill.amountPaid.toStringAsFixed(2),
          bill.amountDue.toStringAsFixed(2),
          bill.paymentMethod,
        ]);
        continue;
      }
      for (final item in bill.items) {
        rows.add([
          bill.invoiceNumber,
          dateText,
          branchNames[bill.branchId] ?? bill.branchId,
          bill.customerName ?? '',
          item.type,
          item.serviceName ?? item.productName ?? '',
          item.quantity,
          item.unitPrice.toStringAsFixed(2),
          item.discountAmount.toStringAsFixed(2),
          (item.unitPrice * item.quantity - item.discountAmount).toStringAsFixed(2),
          item.employeeName ?? state.employeeById(item.employeeId)?.name ?? '',
          item.calculatedCommission.toStringAsFixed(2),
          bill.finalAmount.toStringAsFixed(2),
          bill.amountPaid.toStringAsFixed(2),
          bill.amountDue.toStringAsFixed(2),
          bill.paymentMethod,
        ]);
      }
    }

    if (sorted.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nothing to export in this window.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final scope = _branchId == null
        ? 'all-branches'
        : (branchNames[_branchId] ?? _branchId!).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final from = '${windowStart.year}-${windowStart.month.toString().padLeft(2, '0')}';
    final filename = 'salon-audit-$scope-$from.csv';

    try {
      final result = await exportCsv(filename, toCsv(rows));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            switch (result) {
              CsvExportResult.downloaded =>
                'Exported ${rows.length - 1} line${rows.length == 2 ? '' : 's'} to $filename',
              CsvExportResult.copiedToClipboard =>
                'Copied ${rows.length - 1} line${rows.length == 2 ? '' : 's'} as CSV - paste into a spreadsheet',
              CsvExportResult.shared =>
                '$filename ready - save it or send it from the share menu',
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.accentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Last 6 Months', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Last 6 Months' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF1E3A5F)) : null,
                  onTap: () {
                    setState(() => _timeframe = 'Last 6 Months');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Last 3 Months', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Last 3 Months' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF1E3A5F)) : null,
                  onTap: () {
                    setState(() => _timeframe = 'Last 3 Months');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Current Year', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: _timeframe == 'Current Year' ? const Icon(PhosphorIconsBold.check, color: Color(0xFF1E3A5F)) : null,
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
          const Color(0xFF2F4E79).withValues(alpha: 0.28),
          const Color(0xFF2F4E79).withValues(alpha: 0.0),
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
      ..color = const Color(0xFF2F4E79)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(strokePath, strokePaint);

    // Draw dots and text
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = const Color(0xFF2F4E79)
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
          color: i == points.length - 1 ? const Color(0xFF1E3A5F) : const Color(0xFF94A3B8),
          fontSize: 10.5,
          fontWeight: i == points.length - 1 ? FontWeight.w700 : FontWeight.w600,
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

