import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';

class OwnerDashboardTab extends ConsumerWidget {
  final Function(int) onTabSelected;

  const OwnerDashboardTab({super.key, required this.onTabSelected});

  // Indian-style digit grouping: last 3 digits, then groups of 2
  // (e.g. 312000 -> "3,12,000"), matching the design's currency style.
  String _formatCurrency(double amount) {
    final whole = amount.round().toString();
    if (whole.length <= 3) return 'Rs. $whole';
    final last3 = whole.substring(whole.length - 3);
    final rest = whole.substring(0, whole.length - 3);
    final grouped = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (match) => ',',
    );
    return 'Rs. $grouped,$last3';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(appDataProvider);

    return asyncData.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 32),
              const SizedBox(height: 12),
              Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.slateMedium)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(appDataProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (state) => _buildContent(context, ref, state),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final dashboard = state.dashboard ?? DashboardSummary.empty();
    final customerCount = dashboard.todayCustomersCount;
    final billsCount = dashboard.todayBillCount;
    final staffTotal = state.employees.length;
    final attendanceDisplay = '${dashboard.todayAttendanceCount}/$staffTotal';
    final pendingDiscounts = dashboard.pendingDiscountRequests;
    final lowStockCount = dashboard.lowStockItemCount;

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.slateDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slateLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildSalesCard(
                  title: "Today's Sales",
                  amount: _formatCurrency(dashboard.todaySales),
                  headerIcon: Icons.trending_up_rounded,
                  headerIconColor: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 12),

                _buildSalesCard(
                  title: "This Week's Sales",
                  amount: _formatCurrency(dashboard.weekSales),
                  headerIcon: Icons.calendar_today_outlined,
                  headerIconColor: AppTheme.slateLight,
                ),
                const SizedBox(height: 12),

                _buildSalesCard(
                  title: "This Month's Sales",
                  amount: _formatCurrency(dashboard.monthSales),
                  headerIcon: Icons.calendar_today_outlined,
                  headerIconColor: AppTheme.slateLight,
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
                      const Text(
                        'Payment Breakdown (Today)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slateDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentRow(
                        icon: Icons.payments_outlined,
                        label: 'Cash',
                        amount: _formatCurrency(dashboard.todayCash),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 20),
                      _buildPaymentRow(
                        icon: Icons.credit_card_outlined,
                        label: 'Card',
                        amount: _formatCurrency(dashboard.todayCard),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 20),
                      _buildPaymentRow(
                        icon: Icons.qr_code_2_rounded,
                        label: 'UPI',
                        amount: _formatCurrency(dashboard.todayUpi),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildMetricTile(
                            icon: Icons.people_outline_rounded,
                            value: '$customerCount',
                            label: "Today's Customers",
                            onTap: () => onTabSelected(1),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildMetricTile(
                            icon: Icons.description_outlined,
                            value: '$billsCount',
                            label: 'Bills',
                            onTap: () => onTabSelected(4),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildMetricTile(
                            icon: Icons.calendar_today_outlined,
                            value: attendanceDisplay,
                            label: 'Attendance',
                            onTap: () => onTabSelected(3),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildMetricTile(
                            icon: Icons.local_offer_outlined,
                            value: '$pendingDiscounts',
                            label: 'Pending Discounts',
                            accentColor: AppTheme.accentRed,
                            onTap: () => onTabSelected(9),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildMetricTile(
                            icon: Icons.inventory_2_outlined,
                            value: '$lowStockCount',
                            label: 'Low Stock',
                            accentColor: AppTheme.accentRed,
                            onTap: () => onTabSelected(5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slateDark,
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => onTabSelected(4),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text(
                      'Start Billing',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => onTabSelected(3),
                    icon: const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppTheme.slateDark),
                    label: const Text(
                      'Attendance',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesCard({
    required String title,
    required String amount,
    required IconData headerIcon,
    required Color headerIconColor,
    Widget? bottomBadge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slateLight,
                ),
              ),
              Icon(headerIcon, size: 20, color: headerIconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.slateDark,
              letterSpacing: -0.5,
            ),
          ),
          if (bottomBadge != null) ...[
            const SizedBox(height: 6),
            bottomBadge,
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required IconData icon,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.slateMedium),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slateDark,
          ),
        ),
        const Spacer(),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.slateDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final color = accentColor ?? AppTheme.slateDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color == AppTheme.accentRed ? AppTheme.accentRed : AppTheme.slateMedium),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
