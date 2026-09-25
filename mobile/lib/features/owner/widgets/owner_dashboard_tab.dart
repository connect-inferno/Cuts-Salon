import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../widgets/async_state_views.dart';
import '../../auth/auth_provider.dart';

// The signed-in owner's own initials for their avatar badge - this used to
// be hardcoded to 'TO' (right only for the "Test Owner" demo account), so
// every other real owner would see someone else's initials on their own
// account.
String _ownerInitials(String? name) {
  final initials = (name ?? '').split(' ').where((n) => n.isNotEmpty).map((n) => n[0].toUpperCase()).take(2).join();
  return initials.isEmpty ? 'OW' : initials;
}

class OwnerDashboardTab extends ConsumerWidget {
  final Function(int) onTabSelected;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onSelectBranch;
  // Which branch the header pill is pointed at; null means the whole salon.
  final String? selectedBranchId;

  const OwnerDashboardTab({
    super.key,
    required this.onTabSelected,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onSelectBranch,
    this.selectedBranchId,
  });

  // The salon-wide figures come from getDashboardSummary()'s own aggregate
  // queries. There's no per-branch equivalent of that (and no server to add
  // one), so narrowing to a single branch re-derives the same numbers from
  // the already-loaded bills instead - which is why the header pill says
  // which scope you're looking at. Only the bill-derived fields change;
  // attendance/low-stock/pending-approvals stay salon-wide either way.
  DashboardSummary _scopedSummary(AppData state) {
    final salonWide = state.dashboard ?? DashboardSummary.empty();
    final branchId = selectedBranchId;
    if (branchId == null) return salonWide;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);

    final branchBills = state.bills.where((b) => b.branchId == branchId && b.createdAt != null);
    double sumSince(DateTime from) => branchBills
        .where((b) => !b.createdAt!.isBefore(from))
        .fold(0.0, (sum, b) => sum + b.finalAmount);
    final todayBills = branchBills.where((b) => !b.createdAt!.isBefore(todayStart)).toList();
    double byMethod(String method) => todayBills
        .where((b) => b.paymentMethod == method)
        .fold(0.0, (sum, b) => sum + b.finalAmount);

    return DashboardSummary(
      todaySales: sumSince(todayStart),
      weekSales: sumSince(weekStart),
      monthSales: sumSince(monthStart),
      todayCash: byMethod('CASH'),
      todayCard: byMethod('CARD'),
      todayUpi: byMethod('UPI'),
      todayCustomersCount: todayBills.map((b) => b.customerId).where((id) => id.isNotEmpty).toSet().length,
      todayBillCount: todayBills.length,
      todayAttendanceCount: salonWide.todayAttendanceCount,
      pendingDiscountRequests: salonWide.pendingDiscountRequests,
      lowStockItemCount: salonWide.lowStockItemCount,
    );
  }

  // Currency formatting helper
  String _formatCurrency(double amount) {
    final whole = amount.round().toString();
    if (whole.length <= 3) return '₹$whole';
    final last3 = whole.substring(whole.length - 3);
    final rest = whole.substring(0, whole.length - 3);
    final grouped = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (match) => ',',
    );
    return '₹$grouped,$last3';
  }

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
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
    final dashboard = _scopedSummary(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return RefreshIndicator(
          onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32.0 : 20.0,
              vertical: 20.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1160 : 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isWide) ...[
                      _buildMobileTopBar(context, ref, state),
                      const SizedBox(height: 12),
                    ],
                    // 1. Dashboard Header: Title + Subtitle with live status
                    _buildHeader(),
                    const SizedBox(height: 20),

                    // 2. Bento 2x2 Metric Cards
                    _buildMetricGrid(dashboard),
                    const SizedBox(height: 18),

                    // 3. Revenue Progress Card (Daily Target Overview)
                    _buildRevenueProgressCard(dashboard),
                    const SizedBox(height: 18),

                    // 4. Payment Breakdown Card
                    _buildPaymentBreakdownCard(dashboard),
                    const SizedBox(height: 18),

                    // 5. Quick Actions
                    _buildQuickActionsCard(),
                    const SizedBox(height: 110), // Extra bottom spacing for floating navbar
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileTopBar(BuildContext context, WidgetRef ref, AppData state) {
    final salonName = state.settings?.salonName ?? ref.watch(authControllerProvider).salonName ?? 'Salon';
    final ownerName = ref.watch(authControllerProvider).name;
    final branches = state.branches;
    // Reflects the actual selection, not just branches.first - the picker
    // used to be decorative and this line made that invisible.
    final selected = branches.where((b) => b.id == selectedBranchId);
    final currentBranchName = selected.isNotEmpty
        ? selected.first.name
        // A single-branch salon has nothing to aggregate, so "All Branches"
        // would just be a worse way of naming the one branch it has.
        : (branches.length == 1
            ? branches.first.name
            : (branches.isEmpty ? 'Main Branch' : 'All Branches'));
    final pendingDiscountCount = state.discountRequests.where((r) => r.status == 'PENDING').length;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          children: [
            // Salon Branding Icon & Name
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                PhosphorIconsBold.storefront,
                color: Color(0xFF4F46E5),
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    salonName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Branch Selector Pill
                  InkWell(
                    onTap: onSelectBranch,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsFill.mapPin,
                            size: 11,
                            color: Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              currentBranchName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475467),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            PhosphorIconsBold.caretDown,
                            size: 10,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Notification Bell
            IconButton(
              icon: Badge(
                isLabelVisible: pendingDiscountCount > 0,
                label: Text('$pendingDiscountCount'),
                backgroundColor: const Color(0xFFF04438),
                child: const Icon(
                  PhosphorIconsRegular.bell,
                  color: Color(0xFF334155),
                  size: 22,
                ),
              ),
              onPressed: onOpenNotifications,
              tooltip: 'Notifications',
            ),
            const SizedBox(width: 4),
            // Owner Profile Avatar (Initials "TO")
            InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _ownerInitials(ownerName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              _formatDate(),
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Live Store Data',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricGrid(DashboardSummary dashboard) {
    final avgTicket = dashboard.todayBillCount > 0
        ? (dashboard.todaySales / dashboard.todayBillCount).round()
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. Today's Sales
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.trendUp,
                iconColor: const Color(0xFF4F46E5),
                iconBg: const Color(0xFFEEF2FF),
                badgeText: 'Today',
                badgeTextColor: const Color(0xFF4F46E5),
                badgeBgColor: const Color(0xFFEEF2FF),
                title: "Today's Sales",
                value: _formatCurrency(dashboard.todaySales),
              ),
            ),
            // 2. This Week
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.calendarBlank,
                iconColor: const Color(0xFF9333EA),
                iconBg: const Color(0xFFF3E8FF),
                badgeText: '7 Days',
                badgeTextColor: const Color(0xFF7C3AED),
                badgeBgColor: const Color(0xFFF5F3FF),
                title: 'This Week',
                value: _formatCurrency(dashboard.weekSales),
              ),
            ),
            // 3. Today's Customers
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.users,
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFE6FFFA),
                badgeText: '${dashboard.todayCustomersCount} Visited',
                badgeTextColor: const Color(0xFF2563EB),
                badgeBgColor: const Color(0xFFEFF6FF),
                title: "Today's Customers",
                value: '${dashboard.todayCustomersCount}',
              ),
            ),
            // 4. Bills Today
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.receipt,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFFFBEB),
                badgeText: avgTicket > 0 ? 'Avg ₹$avgTicket' : '0 Bills',
                badgeTextColor: const Color(0xFFB45309),
                badgeBgColor: const Color(0xFFFEF3C7),
                title: 'Bills Today',
                value: '${dashboard.todayBillCount}',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String badgeText,
    required Color badgeTextColor,
    required Color badgeBgColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
          // Top Row: Icon + Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Subtitle / Label
          Text(
            title,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          // Large Bold Value
          Text(
            value,
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueProgressCard(DashboardSummary dashboard) {
    final actual = dashboard.todaySales;
    final planned = dashboard.monthSales > 0
        ? (dashboard.monthSales / (DateTime.now().day > 0 ? DateTime.now().day : 1)).roundToDouble()
        : actual;
    final progress = planned > 0 ? (actual / planned).clamp(0.0, 1.0) : (actual > 0 ? 1.0 : 0.0);
    final percentage = (progress * 100).round();
    final remaining = (planned - actual).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue Progress',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily Target Overview',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actual >= planned && actual > 0 ? 'Target Met' : 'In Progress',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actual vs Planned + Circular Progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: const Color(0xFF475467)),
                              children: [
                                const TextSpan(text: 'Actual: '),
                                TextSpan(
                                  text: _formatCurrency(actual),
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: const Color(0xFF64748B)),
                              children: [
                                const TextSpan(text: 'Planned: '),
                                TextSpan(
                                  text: _formatCurrency(planned),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475467)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Circular Percentage Gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4.5,
                      backgroundColor: const Color(0xFFEEF2FF),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Remaining helper note
          Text(
            // `remaining` is clamped at 0, so a branch (or a salon) with no
            // bills at all had planned == actual == 0 and got congratulated
            // on hitting a target that doesn't exist yet. Same condition the
            // 'Target Met' badge above uses.
            planned <= 0 && actual <= 0
                ? 'No sales recorded yet today'
                : remaining > 0
                    ? '${_formatCurrency(remaining)} needed to reach daily target'
                    : '🎯 Daily target achieved!',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(DashboardSummary dashboard) {
    final total = dashboard.todayCash + dashboard.todayCard + dashboard.todayUpi;
    final displayTotal = total > 0 ? total : dashboard.todaySales;

    final cash = dashboard.todayCash;
    final card = dashboard.todayCard;
    final upi = dashboard.todayUpi;

    final cashPct = displayTotal > 0 ? (cash / displayTotal * 100).round() : 0;
    final cardPct = displayTotal > 0 ? (card / displayTotal * 100).round() : 0;
    final upiPct = displayTotal > 0 ? (upi / displayTotal * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Breakdown',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Collected: ${_formatCurrency(displayTotal)}',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  PhosphorIconsRegular.wallet,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 1. Cash Row
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.money,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            label: 'Cash',
            collectedText: '${_formatCurrency(cash)} collected',
            percent: cashPct,
            barColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 14),

          // 2. Card / POS Row
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.creditCard,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFEFF6FF),
            label: 'Card / POS',
            collectedText: '${_formatCurrency(card)} collected',
            percent: cardPct,
            barColor: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 14),

          // 3. UPI / QR Row
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.qrCode,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFF5F3FF),
            label: 'UPI / QR',
            collectedText: '${_formatCurrency(upi)} collected',
            percent: upiPct,
            barColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChannelRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String collectedText,
    required int percent,
    required Color barColor,
  }) {
    return Row(
      children: [
        // Left Icon
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        // Title & Collected Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                collectedText,
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                  fontSize: 11.5,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Right Percent & Progress Bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$percent%',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 50,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Start Billing Button (Primary)
            Expanded(
              child: InkWell(
                onTap: () => onTabSelected(1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsBold.shoppingCart, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Start Billing',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Attendance Button (Secondary Outlined/Pill)
            Expanded(
              child: InkWell(
                onTap: () => onTabSelected(4),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIconsRegular.calendarBlank, color: Color(0xFF475467), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Attendance',
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', 
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475467),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
