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
import 'widgets/owner_payment_requests_view.dart';
import 'widgets/owner_profile_view.dart';
import 'widgets/owner_whatsapp_page.dart';
import 'widgets/owner_reports_page.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_page_header.dart' show AppPageAction;
import '../../widgets/dues_view.dart';
import '../../widgets/app_page_switcher.dart';
import '../../widgets/app_settings_page.dart';
import '../../widgets/app_sub_page.dart';
import '../../data/models.dart';
import '../../widgets/liquid_nav_bar.dart';
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
              onTap: () => go('Reports', 'Takings, profit, team, clients and stock - month by month',
                  OwnerReportsTab(onStartBill: (c) => _startBillFromReports(context, c))),
            ),
            AppDrawerItem(
              icon: PhosphorIconsRegular.whatsappLogo,
              label: 'WhatsApp',
              onTap: () => go('WhatsApp', 'Automatic messages to clients', const OwnerWhatsAppPage()),
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

  /// Billing, with [customer] already picked as the client.
  void _startBillFor(Customer customer) {
    setState(() => _preselectedCustomerId = customer.id);
    _switchToTab(OwnerTab.billing);
  }

  /// New bill from a client opened in Reports. The client page has already
  /// closed itself; Reports is a page pushed over the tabs, so it closes
  /// too, or the bill would open underneath it.
  void _startBillFromReports(BuildContext context, Customer customer) {
    Navigator.of(context).pop();
    _startBillFor(customer);
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
          subtitle: 'Takings, profit, team, clients and stock - month by month',
          child: OwnerReportsTab(onStartBill: (c) => _startBillFromReports(context, c)),
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
        onStartBill: _startBillFor,
        onOpenNotifications: () => _openNotifications(context),
      ),
      OwnerEmployeesTab(
        key: const ValueKey('team'),
        onOpenNotifications: () => _openNotifications(context),
      ),
    ];
  }
}
