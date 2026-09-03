import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/async_state_views.dart';

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
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
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

    final metricTiles = [
      _buildMetricTile(
        icon: PhosphorIconsRegular.users,
        value: '$customerCount',
        label: "Today's Customers",
        onTap: () => onTabSelected(1),
      ),
      _buildMetricTile(
        icon: PhosphorIconsRegular.fileText,
        value: '$billsCount',
        label: 'Bills',
        onTap: () => onTabSelected(4),
      ),
      _buildMetricTile(
        icon: PhosphorIconsRegular.calendarBlank,
        value: attendanceDisplay,
        label: 'Attendance',
        onTap: () => onTabSelected(3),
      ),
      _buildMetricTile(
        icon: PhosphorIconsRegular.tag,
        value: '$pendingDiscounts',
        label: 'Pending Discounts',
        accentColor: AppTheme.accentRed,
        onTap: () => onTabSelected(9),
      ),
      _buildMetricTile(
        icon: PhosphorIconsRegular.package,
        value: '$lowStockCount',
        label: 'Low Stock',
        accentColor: AppTheme.accentRed,
        onTap: () => onTabSelected(5),
      ),
    ];

    final paymentBreakdownCard = Container(
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
            icon: PhosphorIconsRegular.money,
            label: 'Cash',
            amount: _formatCurrency(dashboard.todayCash),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 20),
          _buildPaymentRow(
            icon: PhosphorIconsRegular.creditCard,
            label: 'Card',
            amount: _formatCurrency(dashboard.todayCard),
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 20),
          _buildPaymentRow(
            icon: PhosphorIconsRegular.qrCode,
            label: 'UPI',
            amount: _formatCurrency(dashboard.todayUpi),
          ),
        ],
      ),
    );

    final quickActionsCard = Container(
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.slateDark,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => onTabSelected(4),
              icon: const Icon(PhosphorIconsRegular.shoppingCart, size: 18),
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
              icon: const Icon(PhosphorIconsRegular.userCheck, size: 18, color: AppTheme.slateDark),
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
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // >=900 is a deliberate mirror of kOwnerMobileBreakpoint - below
          // that the shell drops the sidebar too, so this tab already has
          // the full window width and the narrow single-column layout
          // (designed for that width) is the right one either way.
          final isWide = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0, vertical: 20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1200 : 600),
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
                    SizedBox(height: isWide ? 24 : 18),
                    if (isWide)
                      _buildWideBody(dashboard, paymentBreakdownCard, quickActionsCard, metricTiles)
                    else
                      _buildNarrowBody(dashboard, paymentBreakdownCard, quickActionsCard, metricTiles),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrowBody(
    DashboardSummary dashboard,
    Widget paymentBreakdownCard,
    Widget quickActionsCard,
    List<Widget> metricTiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSalesCard(
          title: "Today's Sales",
          amount: _formatCurrency(dashboard.todaySales),
          headerIcon: PhosphorIconsRegular.trendUp,
          headerIconColor: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 12),
        _buildSalesCard(
          title: "This Week's Sales",
          amount: _formatCurrency(dashboard.weekSales),
          headerIcon: PhosphorIconsRegular.calendarBlank,
          headerIconColor: AppTheme.slateLight,
        ),
        const SizedBox(height: 12),
        _buildSalesCard(
          title: "This Month's Sales",
          amount: _formatCurrency(dashboard.monthSales),
          headerIcon: PhosphorIconsRegular.calendarBlank,
          headerIconColor: AppTheme.slateLight,
        ),
        const SizedBox(height: 16),
        paymentBreakdownCard,
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final tile in metricTiles) SizedBox(width: itemWidth, child: tile)],
            );
          },
        ),
        const SizedBox(height: 24),
        quickActionsCard,
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildWideBody(
    DashboardSummary dashboard,
    Widget paymentBreakdownCard,
    Widget quickActionsCard,
    List<Widget> metricTiles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSalesCard(
                title: "Today's Sales",
                amount: _formatCurrency(dashboard.todaySales),
                headerIcon: PhosphorIconsRegular.trendUp,
                headerIconColor: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSalesCard(
                title: "This Week's Sales",
                amount: _formatCurrency(dashboard.weekSales),
                headerIcon: PhosphorIconsRegular.calendarBlank,
                headerIconColor: AppTheme.slateLight,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSalesCard(
                title: "This Month's Sales",
                amount: _formatCurrency(dashboard.monthSales),
                headerIcon: PhosphorIconsRegular.calendarBlank,
                headerIconColor: AppTheme.slateLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: paymentBreakdownCard),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: quickActionsCard),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (int i = 0; i < metricTiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: metricTiles[i]),
            ],
          ],
        ),
        const SizedBox(height: 32),
      ],
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
