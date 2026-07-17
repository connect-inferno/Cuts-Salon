import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/owner_dashboard_tab.dart';
import 'widgets/owner_customers_employees_tab.dart';
import 'widgets/owner_billing_inventory_expenses_tab.dart';
import 'widgets/owner_management_tabs.dart';
import 'widgets/chart_widgets.dart';

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
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.badge_outlined,
    Icons.calendar_today_outlined,
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
    Icons.money_off_outlined,
    Icons.analytics_outlined,
    Icons.store_outlined,
    Icons.percent_outlined,
    Icons.settings_outlined,
  ];

  // Primary tabs available via the phone bottom bar
  static const List<int> _bottomTabIndexes = [0, 1, 2, 4, 6];

  Widget _buildSidebar(BuildContext context, {required bool isMobile}) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isMobile
            ? null
            : Border(
                right: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Owner Portal',
                        style: TextStyle(
                          color: Colors.grey,
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
            child: Text(
              'v1.0.0 Client Demo',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kOwnerMobileBreakpoint;

    int bottomSelectedIndex = _bottomTabIndexes.indexOf(_activeTabIndex);
    if (bottomSelectedIndex == -1) bottomSelectedIndex = 0;

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
                child: _buildSidebar(context, isMobile: true),
              ),
            )
          : null,
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: bottomSelectedIndex,
              onDestinationSelected: (idx) {
                setState(() {
                  _activeTabIndex = _bottomTabIndexes[idx];
                });
              },
              destinations: [
                for (final tabIdx in _bottomTabIndexes)
                  NavigationDestination(
                    icon: Icon(_tabIcons[tabIdx]),
                    label: _tabNames[tabIdx].split(' ').first,
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: Container(
          color: Colors.grey.shade50,
          width: double.infinity,
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
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return OwnerDashboardTab(
          onTabSelected: (idx) {
            setState(() {
              _activeTabIndex = idx;
            });
          },
        );
      case 1:
        return const OwnerCustomersTab();
      case 2:
        return const OwnerEmployeesTab();
      case 3:
        return const OwnerAttendanceTab();
      case 4:
        return const OwnerBillingTab();
      case 5:
        return const OwnerInventoryTab();
      case 6:
        return const OwnerExpensesTab();
      case 7:
        return const OwnerReportsTab();
      case 8:
        return const OwnerBranchTab();
      case 9:
        return const OwnerDiscountsTab();
      case 10:
        return const OwnerSettingsTab();
      default:
        return const Center(child: Text('Coming Soon Screen'));
    }
  }
}

// --- REPORTS TAB ---

class OwnerReportsTab extends StatelessWidget {
  const OwnerReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        final Widget chart1 = CustomLineChart(
          title: 'Revenue Projections',
          subtitle: 'Next 6 months forecasted trend',
          values: const [920000, 950000, 1020000, 1100000, 1050000, 1200000],
          labels: const ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
          color: Colors.teal,
        );

        final Widget chart2 = CustomBarChart(
          title: 'Service Popularity',
          subtitle: 'Revenue generated per service category this month',
          values: const [24000, 18000, 15000, 32000, 45000, 12000],
          labels: const ['Hair', 'Skincare', 'Nails', 'Color', 'Facial', 'Spa'],
          color: Colors.indigo,
        );

        final Widget metric1 = _buildReportMetricCard(
          'Average Ticket Value (ATV)',
          '₹2,450',
          '+4.2% from last month',
          Colors.green,
        );

        final Widget metric2 = _buildReportMetricCard(
          'Client Retention Index',
          '84.2%',
          '+1.8% vs industry standard',
          Colors.indigo,
        );

        final Widget metric3 = _buildReportMetricCard(
          'Staff Efficiency Score',
          '92.4%',
          'Excellent productivity rating',
          Colors.purple,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analytical Reports',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
              const SizedBox(height: 4),
              const Text(
                'Business performance reports generated automatically.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              if (isMobile) ...[
                chart1,
                const SizedBox(height: 20),
                chart2,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart1),
                    const SizedBox(width: 20),
                    Expanded(child: chart2),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              if (isMobile) ...[
                metric1,
                const SizedBox(height: 16),
                metric2,
                const SizedBox(height: 16),
                metric3,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: metric1),
                    const SizedBox(width: 16),
                    Expanded(child: metric2),
                    const SizedBox(width: 16),
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

  Widget _buildReportMetricCard(String title, String value, String subtitle, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
