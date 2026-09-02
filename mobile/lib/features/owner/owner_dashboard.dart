import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../data/app_data_provider.dart';
import '../auth/auth_provider.dart';
import 'widgets/owner_dashboard_tab.dart';
import 'widgets/owner_customers_employees_tab.dart';
import 'widgets/owner_billing_inventory_expenses_tab.dart';
import 'widgets/owner_management_tabs.dart';
import 'widgets/chart_widgets.dart';
import '../../widgets/app_page_switcher.dart';

const double kOwnerMobileBreakpoint = 900;

class OwnerDashboard extends ConsumerStatefulWidget {
  const OwnerDashboard({super.key});

  @override
  ConsumerState<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends ConsumerState<OwnerDashboard> {
  int _activeTabIndex = 0;

  final List<String> _tabNames = [
    'Dashboard',
    'Customers',
    'Employees',
    'Attendance',
    'Billing Checkout',
    'Inventory Catalog',
    'Expenses Log',
    'Analytical Reports',
    'Branch Management',
    'Discount Requests',
    'System Settings',
  ];

  final List<IconData> _tabIcons = [
    Icons.grid_view_rounded,
    Icons.people_alt_outlined,
    Icons.badge_outlined,
    Icons.calendar_today_outlined,
    Icons.receipt_long_rounded,
    Icons.inventory_2_outlined,
    Icons.money_off_outlined,
    Icons.analytics_outlined,
    Icons.store_outlined,
    Icons.percent_outlined,
    Icons.settings_outlined,
  ];

  Widget _buildSidebar(BuildContext context, {required bool isMobile}) {
    final pendingDiscountCount = ref.watch(appDataProvider).valueOrNull?.discountRequests.where((r) => r.status == 'PENDING').length ?? 0;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile
            ? null
            : const Border(
                right: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
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
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                        'Owner Portal',
                        style: TextStyle(
                          color: AppTheme.slateLight,
                          fontSize: 10,
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
                          if (index == 9 && pendingDiscountCount > 0) // Discount badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingDiscountCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final moreIndices = [2, 3, 6, 7, 8, 9, 10];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    'More Management Options',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.slateDark),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final idx in moreIndices)
                      SizedBox(
                        width: (MediaQuery.of(context).size.width - 44) / 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _activeTabIndex = idx;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _activeTabIndex == idx ? AppTheme.primaryLight : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(_tabIcons[idx], size: 18, color: _activeTabIndex == idx ? AppTheme.primaryBlue : AppTheme.slateMedium),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _tabNames[idx],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _activeTabIndex == idx ? AppTheme.primaryBlue : AppTheme.slateDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(authControllerProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kOwnerMobileBreakpoint;
    final pendingDiscountCount = ref.watch(appDataProvider).valueOrNull?.discountRequests.where((r) => r.status == 'PENDING').length ?? 0;

    // Map 5 Bottom Nav Bar Items (Stitch Spec)
    // 0: Dashboard, 1: Billing (index 4), 2: Customers (index 1), 3: Catalog (index 5), 4: More
    int navIndex = 0;
    if (_activeTabIndex == 4) {
      navIndex = 1;
    } else if (_activeTabIndex == 1) {
      navIndex = 2;
    } else if (_activeTabIndex == 5) {
      navIndex = 3;
    } else if (_activeTabIndex != 0) {
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
                if (_activeTabIndex != 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.slateMedium),
                    onPressed: () {
                      setState(() {
                        _activeTabIndex = 0;
                      });
                    },
                    tooltip: 'Back to Overview',
                  ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.slateLight, size: 20),
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).logout();
                  },
                  tooltip: 'Logout',
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
                child: _buildSidebar(context, isMobile: true),
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
                    setState(() => _activeTabIndex = 4); // Billing
                  } else if (idx == 2) {
                    setState(() => _activeTabIndex = 1); // Customers
                  } else if (idx == 3) {
                    setState(() => _activeTabIndex = 5); // Catalog
                  } else if (idx == 4) {
                    _showMoreMenu(context);
                  }
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.grid_view_rounded, size: 20),
                    selectedIcon: Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Dashboard',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.receipt_long_rounded, size: 20),
                    selectedIcon: Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Billing',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.people_alt_outlined, size: 20),
                    selectedIcon: Icon(Icons.people_alt_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Customers',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined, size: 20),
                    selectedIcon: Icon(Icons.inventory_2_rounded, size: 20, color: AppTheme.primaryBlue),
                    label: 'Catalog',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: pendingDiscountCount > 0,
                      label: Text('$pendingDiscountCount'),
                      backgroundColor: AppTheme.accentRed,
                      child: const Icon(Icons.menu_rounded, size: 20),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: pendingDiscountCount > 0,
                      label: Text('$pendingDiscountCount'),
                      backgroundColor: AppTheme.accentRed,
                      child: const Icon(Icons.menu_rounded, size: 20, color: AppTheme.primaryBlue),
                    ),
                    label: 'More',
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: isMobile
            ? _buildActiveTabContent()
            : Row(
                children: [
                  _buildSidebar(context, isMobile: false),
                  Expanded(
                    child: _buildActiveTabContent(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    return AppPageSwitcher(child: _buildActiveTabContentRaw());
  }

  Widget _buildActiveTabContentRaw() {
    switch (_activeTabIndex) {
      case 0:
        return OwnerDashboardTab(
          key: const ValueKey('dashboard'),
          onTabSelected: (idx) {
            setState(() {
              _activeTabIndex = idx;
            });
          },
        );
      case 1:
        return const OwnerCustomersTab(key: ValueKey('customers'));
      case 2:
        return const OwnerEmployeesTab(key: ValueKey('employees'));
      case 3:
        return const OwnerAttendanceTab(key: ValueKey('attendance'));
      case 4:
        return const OwnerBillingTab(key: ValueKey('billing'));
      case 5:
        return const OwnerInventoryTab(key: ValueKey('inventory'));
      case 6:
        return const OwnerExpensesTab(key: ValueKey('expenses'));
      case 7:
        return const OwnerReportsTab(key: ValueKey('reports'));
      case 8:
        return const OwnerBranchTab(key: ValueKey('branch'));
      case 9:
        return const OwnerDiscountsTab(key: ValueKey('discounts'));
      case 10:
        return const OwnerSettingsTab(key: ValueKey('settings'));
      default:
        return const Center(key: ValueKey('fallback'), child: Text('Coming Soon Screen'));
    }
  }
}

// --- REPORTS TAB ---

const List<String> _kMonthAbbrevs = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class OwnerReportsTab extends ConsumerWidget {
  const OwnerReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text(err.toString())),
      data: (state) => _buildContent(context, state),
    );
  }

  Widget _buildContent(BuildContext context, AppData state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

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
        final hasRevenueData = revenueByMonth.any((v) => v > 0);

        final categoryRevenue = <String, double>{};
        for (final bill in state.bills) {
          for (final item in bill.items) {
            if (item.type != 'SERVICE') continue;
            final matches = state.services.where((s) => s.id == item.serviceId);
            final categoryName = matches.isNotEmpty ? (matches.first.categoryName ?? 'Uncategorized') : 'Uncategorized';
            final lineTotal = (item.unitPrice * item.quantity) - item.discountAmount;
            categoryRevenue[categoryName] = (categoryRevenue[categoryName] ?? 0) + lineTotal;
          }
        }
        final sortedCategories = categoryRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final topCategories = sortedCategories.take(6).toList();

        final totalRevenue = state.bills.fold<double>(0, (s, b) => s + b.finalAmount);
        final atv = state.bills.isEmpty ? 0.0 : totalRevenue / state.bills.length;

        final billsByCustomer = <String, int>{};
        for (final b in state.bills) {
          billsByCustomer[b.customerId] = (billsByCustomer[b.customerId] ?? 0) + 1;
        }
        final customersWithBills = billsByCustomer.length;
        final repeatCustomers = billsByCustomer.values.where((c) => c > 1).length;
        final retentionPct = customersWithBills == 0 ? 0.0 : (repeatCustomers / customersWithBills) * 100;

        final monthAttendance = state.attendance.where((a) => a.date != null && a.date!.month == now.month && a.date!.year == now.year).toList();
        final presentCount = monthAttendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
        final staffAttendanceRate = monthAttendance.isEmpty ? 0.0 : (presentCount / monthAttendance.length) * 100;

        final Widget chart1 = hasRevenueData
            ? CustomLineChart(
                title: 'Revenue Trend',
                subtitle: 'Total billed revenue over the last 6 months',
                values: revenueByMonth,
                labels: monthLabels,
                color: AppTheme.primaryBlue,
              )
            : _buildEmptyChartCard('Revenue Trend', 'No billing history yet — this fills in once bills start coming in.');

        final Widget chart2 = topCategories.isEmpty
            ? _buildEmptyChartCard('Service Popularity', 'No service sales recorded yet.')
            : CustomBarChart(
                title: 'Service Popularity',
                subtitle: 'Revenue generated per service category (all-time)',
                values: topCategories.map((e) => e.value).toList(),
                labels: topCategories.map((e) => e.key).toList(),
                color: AppTheme.primaryDark,
              );

        final Widget metric1 = _buildReportMetricCard(
          'Average Ticket Value',
          'Rs. ${atv.toStringAsFixed(0)}',
          'Across ${state.bills.length} bill${state.bills.length == 1 ? '' : 's'} all-time',
          AppTheme.accentGreen,
        );

        final Widget metric2 = _buildReportMetricCard(
          'Client Retention Rate',
          '${retentionPct.toStringAsFixed(0)}%',
          '$repeatCustomers of $customersWithBills billed customers returned',
          AppTheme.primaryBlue,
        );

        final Widget metric3 = _buildReportMetricCard(
          'Staff Attendance Rate',
          '${staffAttendanceRate.toStringAsFixed(0)}%',
          'This month, across all staff',
          AppTheme.slateMedium,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analytical Reports',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppTheme.slateDark),
              ),
              const SizedBox(height: 4),
              const Text(
                'Business performance computed live from your billing and attendance records.',
                style: TextStyle(color: AppTheme.slateLight, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (isMobile) ...[
                chart1,
                const SizedBox(height: 16),
                chart2,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart1),
                    const SizedBox(width: 16),
                    Expanded(child: chart2),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (isMobile) ...[
                metric1,
                const SizedBox(height: 12),
                metric2,
                const SizedBox(height: 12),
                metric3,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: metric1),
                    const SizedBox(width: 14),
                    Expanded(child: metric2),
                    const SizedBox(width: 14),
                    Expanded(child: metric3),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyChartCard(String title, String message) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle)),
      padding: const EdgeInsets.all(20.0),
      height: 244,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Expanded(
            child: Center(
              child: Icon(Icons.insert_chart_outlined_rounded, size: 40, color: AppTheme.borderSubtle),
            ),
          ),
          Text(message, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildReportMetricCard(String title, String value, String subtitle, Color color) {
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
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.slateLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.slateLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
