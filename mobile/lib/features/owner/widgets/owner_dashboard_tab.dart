import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../salon_state.dart';

class OwnerDashboardTab extends ConsumerWidget {
  final Function(int) onTabSelected;

  const OwnerDashboardTab({super.key, required this.onTabSelected});

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      return 'Rs. ${lakhs.toStringAsFixed(lakhs.truncateToDouble() == lakhs ? 0 : 2)},000';
    } else if (amount >= 1000) {
      final thousands = (amount / 1000).floor();
      final remainder = (amount % 1000).toInt();
      return 'Rs. $thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(salonStateProvider);

    final cashCollected = state.cashCollected > 0 ? state.cashCollected : 4000.0;
    const cardCollected = 6000.0;
    final upiCollected = state.upiCollected > 0 ? state.upiCollected : 2450.0;

    final customerCount = state.customers.isNotEmpty ? state.customers.length : 18;
    final billsCount = state.bills.isNotEmpty ? state.bills.length : 15;
    final staffPresent = state.employees.where((e) => e.status == 'Present').length;
    final staffTotal = state.employees.isNotEmpty ? state.employees.length : 6;
    final attendanceDisplay = state.employees.isNotEmpty ? '$staffPresent/$staffTotal' : '5/6';
    final pendingDiscounts = state.discountRequests.isNotEmpty ? state.discountRequests.where((d) => d.status.toUpperCase() == 'PENDING').length : 2;
    final lowStockCount = state.inventory.isNotEmpty ? state.inventory.where((i) => i.currentStock <= i.minStockAlertThreshold).length : 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: "Overview" + "Last updated: Just now"
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
                      'Last updated: Just now',
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

              // 1. Today's Sales Card
              _buildSalesCard(
                title: "Today's Sales",
                amount: 'Rs. 12,450',
                headerIcon: Icons.trending_up_rounded,
                headerIconColor: AppTheme.primaryBlue,
                bottomBadge: const Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.accentGreen),
                    SizedBox(width: 4),
                    Text(
                      '12% vs yesterday',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. This Week's Sales Card
              _buildSalesCard(
                title: "This Week's Sales",
                amount: 'Rs. 84,200',
                headerIcon: Icons.calendar_today_outlined,
                headerIconColor: AppTheme.slateLight,
              ),
              const SizedBox(height: 12),

              // 3. This Month's Sales Card
              _buildSalesCard(
                title: "This Month's Sales",
                amount: 'Rs. 3,12,000',
                headerIcon: Icons.calendar_today_outlined,
                headerIconColor: AppTheme.slateLight,
              ),
              const SizedBox(height: 16),

              // 4. Payment Breakdown (Today)
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
                      amount: _formatCurrency(cashCollected),
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildPaymentRow(
                      icon: Icons.credit_card_outlined,
                      label: 'Card',
                      amount: _formatCurrency(cardCollected),
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),
                    _buildPaymentRow(
                      icon: Icons.qr_code_2_rounded,
                      label: 'UPI',
                      amount: _formatCurrency(upiCollected),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. 2x3 Metric Cards Grid
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

              // 6. Quick Actions Section
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slateDark,
                ),
              ),
              const SizedBox(height: 12),

              // Primary Action: Start Billing
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

              // Secondary Action: Attendance
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
