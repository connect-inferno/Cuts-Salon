import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../salon_state.dart';
import 'chart_widgets.dart';

class OwnerDashboardTab extends ConsumerWidget {
  final Function(int) onTabSelected;

  const OwnerDashboardTab({super.key, required this.onTabSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salonStateProvider);

    return LayoutBuilder(builder: (context, constraints) {
      final isTight = constraints.maxWidth < 700;
      return SingleChildScrollView(
      padding: EdgeInsets.all(isTight ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back, Alex',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here is what\'s happening in your salons today.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              // Branch quick switcher visual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'All Branches (3)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Core KPI Cards Grid
          _buildKpiGrid(context, state),
          const SizedBox(height: 32),

          // Charts & Analytics Section
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              if (isMobile) {
                return Column(
                  children: [
                    CustomLineChart(
                      title: 'Revenue Trend',
                      subtitle: 'Hourly performance for today',
                      values: const [8000, 12000, 15000, 11000, 19000, 24000, 34250],
                      labels: const ['09 AM', '11 AM', '01 PM', '03 PM', '05 PM', '07 PM', '09 PM'],
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActionsCard(context),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomLineChart(
                      title: 'Revenue Trend',
                      subtitle: 'Hourly performance for today',
                      values: const [8000, 12000, 15000, 11000, 19000, 24000, 34250],
                      labels: const ['09 AM', '11 AM', '01 PM', '03 PM', '05 PM', '07 PM', '09 PM'],
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 1,
                    child: _buildQuickActionsCard(context),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Recent Activities / Bills
          _buildRecentActivities(context, state),
        ],
      ),
    );
    });
  }

  Widget _buildKpiGrid(BuildContext context, SalonState state) {
    final kpis = [
      _KpiData(
        title: 'Today\'s Sales',
        value: '₹${state.todaySales.toStringAsFixed(0)}',
        icon: Icons.today_outlined,
        color: Colors.green,
        subtitle: 'Live update from billing',
      ),
      _KpiData(
        title: 'Weekly Sales',
        value: '₹${state.weeklySales.toStringAsFixed(0)}',
        icon: Icons.calendar_view_week_outlined,
        color: Colors.blueAccent,
        subtitle: 'This week\'s turnover',
      ),
      _KpiData(
        title: 'Monthly Sales',
        value: '₹${state.monthlySales.toStringAsFixed(0)}',
        icon: Icons.calendar_month_outlined,
        color: Colors.purple,
        subtitle: 'Current billing month',
      ),
      _KpiData(
        title: 'UPI Collected',
        value: '₹${state.upiCollected.toStringAsFixed(0)}',
        icon: Icons.qr_code_2_outlined,
        color: Colors.teal,
        subtitle: 'Digital transactions',
      ),
      _KpiData(
        title: 'Cash Collected',
        value: '₹${state.cashCollected.toStringAsFixed(0)}',
        icon: Icons.payments_outlined,
        color: Colors.amber.shade800,
        subtitle: 'Cash in drawer',
      ),
      _KpiData(
        title: 'Pending Payments',
        value: '₹${state.pendingPayments.toStringAsFixed(0)}',
        icon: Icons.hourglass_empty_outlined,
        color: Colors.redAccent,
        subtitle: 'Credit collections due',
      ),
      _KpiData(
        title: 'Today\'s Customers',
        value: '${state.todayCustomersCount}',
        icon: Icons.people_outline_outlined,
        color: Colors.indigo,
        subtitle: 'Total footfall today',
      ),
      _KpiData(
        title: 'Today\'s Attendance',
        value: '${state.todayAttendanceCount}/${state.employees.length}',
        icon: Icons.assignment_turned_in_outlined,
        color: Colors.pink,
        subtitle: 'Staff present clock-in',
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final crossAxisCount = w < 500
          ? 2
          : w < 900
              ? 3
              : 4;
      final isTight = w < 700;
      return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTight ? 12 : 16,
        mainAxisSpacing: isTight ? 12 : 16,
        childAspectRatio: isTight ? 1.4 : 1.8,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        kpi.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(kpi.icon, color: kpi.color, size: 22),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kpi.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kpi.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    });
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    final actions = [
      _ActionData('Billing', Icons.receipt_long, 4, Colors.amber),
      _ActionData('Customers', Icons.people_outline, 1, Colors.indigo),
      _ActionData('Employees', Icons.badge_outlined, 2, Colors.purple),
      _ActionData('Attendance', Icons.calendar_today_outlined, 3, Colors.pink),
      _ActionData('Inventory', Icons.inventory_2_outlined, 5, Colors.blue),
      _ActionData('Expenses', Icons.money_off_outlined, 6, Colors.redAccent),
      _ActionData('Reports', Icons.analytics_outlined, 7, Colors.teal),
      _ActionData('Discounts', Icons.percent_outlined, 9, Colors.orange),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final act = actions[index];
                return InkWell(
                  onTap: () => onTabSelected(act.tabIndex),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: act.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: act.color.withOpacity(0.15)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(act.icon, color: act.color, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          act.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context, SalonState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => onTabSelected(4),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.bills.length > 5 ? 5 : state.bills.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 1),
              itemBuilder: (context, index) {
                final bill = state.bills[index];
                final isPending = bill.paymentMethod == 'Pending';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              radius: 20,
                              child: Icon(
                                Icons.receipt_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${bill.billNo} • ${bill.services.join(", ")}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${bill.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.red.shade50 : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bill.paymentMethod,
                              style: TextStyle(
                                color: isPending ? Colors.red.shade700 : Colors.green.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  _KpiData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });
}

class _ActionData {
  final String name;
  final IconData icon;
  final int tabIndex;
  final Color color;

  _ActionData(this.name, this.icon, this.tabIndex, this.color);
}
