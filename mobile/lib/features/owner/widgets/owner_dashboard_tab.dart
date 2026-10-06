import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/liquid_nav_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/models.dart';
import '../../../theme.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_settings_page.dart';
import '../../../widgets/async_state_views.dart';

class OwnerDashboardTab extends ConsumerWidget {
  // Named for where they go rather than for a tab index. The old
  // `onTabSelected(int)` meant this widget had to know that 1 was Billing
  // and 4 was Attendance - numbering that lived in another file and broke
  // silently the moment the tab list was reordered.
  final VoidCallback onOpenBilling;
  final VoidCallback onOpenAttendance;
  // Where the four metric cards go when tapped. Each one answers half a
  // question ("4 bills today") and the page behind it answers the rest
  // ("which four"), so a card that does nothing is a dead end.
  final VoidCallback? onOpenClients;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onSelectBranch;
  // Which branch the header pill is pointed at; null means the whole salon.
  final String? selectedBranchId;

  const OwnerDashboardTab({
    super.key,
    required this.onOpenBilling,
    required this.onOpenAttendance,
    this.onOpenClients,
    this.onOpenReports,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onOpenSettings,
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
    // Collected, not billed - matches getDashboardSummary's salon-wide
    // version, so a part-paid bill only contributes what was handed over,
    // and a later settlement counts under the method it was paid by.
    double byMethod(String method) => todayBills.fold(0.0, (sum, b) => sum + (b.collectedByMethod[method] ?? 0));

    return DashboardSummary(
      todaySales: sumSince(todayStart),
      weekSales: sumSince(weekStart),
      monthSales: sumSince(monthStart),
      todayCash: byMethod('CASH'),
      todayCard: byMethod('CARD'),
      todayUpi: byMethod('UPI'),
      todayOutstanding: todayBills.fold(0.0, (sum, b) => sum + b.amountDue),
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
      data: (state) => Container(
        color: const Color(0xFFF4F6FB),
        child: Column(
          children: [
            // The same header every other page wears. This page used to
            // draw two: a "salon name + branch pill + bell + avatar" bar,
            // and then a 28px "Dashboard" title under it - so the top third
            // of the screen was chrome before a single number appeared.
            AppPageHeader(
              title: 'Home',
              subtitle: _headerSubtitle(state),
              actions: [
                AppPageAction(
                  icon: PhosphorIconsRegular.bell,
                  tooltip: 'Notifications',
                  badgeCount: state.pendingDiscountCount,
                  onTap: () => onOpenNotifications?.call(),
                ),
                appSettingsAction(
                  tooltip: 'Salon settings',
                  onTap: () => onOpenSettings?.call(),
                ),
              ],
            ),
            Expanded(child: _buildContent(context, ref, state)),
          ],
        ),
      ),
    );
  }

  /// Date plus the scope the numbers below are for, so the header says what
  /// you are looking at instead of leaving the branch pill to imply it.
  String _headerSubtitle(AppData state) {
    final branches = state.branches;
    final selected = branches.where((b) => b.id == selectedBranchId);
    if (selected.isNotEmpty) return '${_formatDate()} · ${selected.first.name}';
    if (branches.length > 1) return '${_formatDate()} · All branches';
    return _formatDate();
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppData state) {
    final dashboard = _scopedSummary(state);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return RefreshIndicator(
          color: AppTheme.primaryBlue,
          onRefresh: () => ref.read(appDataProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 20.0 + LiquidNavBar.barInset),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 1160 : 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero gradient banner with today's revenue
                    _buildHeroBanner(context, ref, dashboard, state),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),


                          // 2. Metric Cards grid
                          _buildMetricGrid(dashboard, state),
                          const SizedBox(height: 20),

                          // 3. Revenue Progress Card
                          _buildRevenueProgressCard(context, ref, dashboard, state),
                          const SizedBox(height: 20),

                          // 4. Payment Breakdown Card
                          _buildPaymentBreakdownCard(dashboard),
                          const SizedBox(height: 20),

                          // 5. Quick Actions
                          _buildQuickActionsCard(),
                          const SizedBox(height: 88),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // ─── Hero Banner ────────────────────────────────────────────────────────────

  Widget _buildHeroBanner(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary dashboard,
    AppData state,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles for depth
          Positioned(
            top: -28,
            right: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -18,
            left: -18,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 80,
            child: Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.branches.length > 1) ...[
                  _buildBranchPill(state),
                  const SizedBox(height: 18),
                ],
                Text(
                  "TODAY'S REVENUE",
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(dashboard.todaySales),
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsBold.calendarBlank, size: 12, color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 6),
                      Text(
                        'This week  ${_formatCurrency(dashboard.weekSales)}',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchPill(AppData state) {
    final selected = state.branches.where((b) => b.id == selectedBranchId);
    final label = selected.isNotEmpty ? selected.first.name : 'All branches';

    return InkWell(
      onTap: onSelectBranch,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIconsFill.mapPin, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 5),
            Icon(PhosphorIconsBold.caretDown, size: 11, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid(DashboardSummary dashboard, AppData state) {
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
            // 1. Today's Customers
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.users,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: const Color(0xFF0D9488),
                accentBg: const Color(0xFFE6FFFA),
                badgeText: '${dashboard.todayCustomersCount} Visited',
                title: "Today's Clients",
                value: '${dashboard.todayCustomersCount}',
                onTap: onOpenClients,
              ),
            ),
            // 2. Bills Today
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.receipt,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: const Color(0xFFD97706),
                accentBg: const Color(0xFFFFFBEB),
                badgeText: avgTicket > 0 ? 'Avg ₹$avgTicket' : '0 Bills',
                title: 'Bills Today',
                value: '${dashboard.todayBillCount}',
                onTap: onOpenBilling,
              ),
            ),
            // 3. Attendance
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.identificationCard,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: const Color(0xFF7C3AED),
                accentBg: const Color(0xFFF5F3FF),
                badgeText: 'Staff In',
                title: 'Attendance',
                value: '${dashboard.todayAttendanceCount}',
                onTap: onOpenAttendance,
              ),
            ),
            // 4. Low Stock
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                icon: PhosphorIconsBold.warningCircle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                accentColor: const Color(0xFFDC2626),
                accentBg: const Color(0xFFFEF2F2),
                badgeText: dashboard.lowStockItemCount > 0 ? 'Low Stock' : 'All Good',
                title: 'Low Stock',
                value: '${dashboard.lowStockItemCount}',
                onTap: onOpenReports,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required LinearGradient gradient,
    required Color accentColor,
    required Color accentBg,
    required String badgeText,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: card,
      ),
    );
  }

  /// Sets (or clears) the salon's daily takings goal.
  ///
  /// This is one field on the `settings` document AppData already carries, so
  /// saving it costs a single write and the card re-renders off the patched
  /// snapshot - no reload, no extra read. Owner-only by firestore.rules,
  /// which is the same gate every other settings write goes through.
  void _showDailyTargetDialog(BuildContext context, WidgetRef ref, double current) {
    final controller = TextEditingController(text: current > 0 ? current.round().toString() : '');
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Daily revenue target',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What the salon aims to take in a day. Leave it empty to go '
                'back to showing the running daily average instead.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Target (Rs.)',
                  prefixIcon: Icon(PhosphorIconsRegular.target, size: 19),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final raw = controller.text.trim();
                      // Empty clears the target; anything else has to be a
                      // number, so a typo cannot silently write 0 and make
                      // the card claim the goal was met at the first rupee.
                      final value = raw.isEmpty ? 0.0 : double.tryParse(raw);
                      if (value == null || value < 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a number, or leave it empty to clear the target.'),
                            backgroundColor: AppTheme.accentRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(appDataProvider.notifier)
                            .updateSettings({'dailyRevenueTarget': value});
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.accentRed,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueProgressCard(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary dashboard,
    AppData state,
  ) {
    final actual = dashboard.todaySales;
    // The target the owner set, if they set one. Before this existed the
    // "planned" figure was this month's takings divided by the days elapsed -
    // a running average dressed up as a goal, which meant the card could
    // never be beaten by much and there was nowhere to change it. An explicit
    // target of 0 means "not set", and the old average is the fallback so the
    // card still says something useful on day one.
    final configured = state.settings?.dailyRevenueTarget ?? 0;
    final isConfigured = configured > 0;
    final planned = isConfigured
        ? configured
        : (dashboard.monthSales > 0
            ? (dashboard.monthSales / (DateTime.now().day > 0 ? DateTime.now().day : 1)).roundToDouble()
            : actual);
    final progress = planned > 0 ? (actual / planned).clamp(0.0, 1.0) : (actual > 0 ? 1.0 : 0.0);
    final percentage = (progress * 100).round();
    final remaining = (planned - actual).clamp(0.0, double.infinity);

    final isAchieved = planned > 0 && actual >= planned;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(PhosphorIconsBold.target, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Revenue Progress',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isConfigured ? 'Daily Target Overview' : 'Daily average so far',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // The badge judges the day against `planned`, so the control
              // that sets `planned` belongs next to it.
              InkWell(
                onTap: () => _showDailyTargetDialog(context, ref, configured),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                  decoration: BoxDecoration(
                    gradient: isAchieved
                        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                        : const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !isConfigured
                            ? 'Set target'
                            : (isAchieved ? '🎯 Met!' : 'In Progress'),
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(PhosphorIconsBold.caretRight, size: 9, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Arc gauge + stat column
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildArcGauge(percentage, isAchieved),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressStat('Actual', _formatCurrency(actual), const Color(0xFF4F46E5)),
                    const SizedBox(height: 10),
                    _buildProgressStat('Target', _formatCurrency(planned), const Color(0xFF94A3B8)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 7,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAchieved ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      planned <= 0 && actual <= 0
                          ? 'No sales recorded yet today'
                          : remaining > 0
                              ? '${_formatCurrency(remaining)} to go'
                              : '🎯 Daily target achieved!',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isAchieved ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArcGauge(int percentage, bool achieved) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _ArcGaugePainter(
          progress: (percentage / 100).clamp(0.0, 1.0),
          achieved: achieved,
        ),
        child: Center(
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: achieved ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdownCard(DashboardSummary dashboard) {
    final cash = dashboard.todayCash;
    final upi = dashboard.todayUpi;
    // Card isn't offered at checkout any more, but a pay-later balance can
    // still be settled by card (Clients > Pending > Collect), so card money
    // does arrive. It used to be left out of every figure here - a balance
    // cleared by card vanished from the dashboard - so it is counted, and
    // its row shown only on a day that actually has some.
    final card = dashboard.todayCard;
    // Pending: billed today but not handed over. It is deliberately kept out
    // of "Total Collected" - it is money owed, not money taken.
    final pending = dashboard.todayOutstanding;

    final collected = cash + upi + card;
    // Shares of everything billed today, so the rows use one base and add up.
    final billedTotal = collected + pending;

    final cashPct = billedTotal > 0 ? (cash / billedTotal * 100).round() : 0;
    final upiPct = billedTotal > 0 ? (upi / billedTotal * 100).round() : 0;
    final cardPct = billedTotal > 0 ? (card / billedTotal * 100).round() : 0;
    final pendingPct =
        billedTotal > 0 ? (pending / billedTotal * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(PhosphorIconsBold.wallet, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Breakdown',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Collected: ${_formatCurrency(collected)}',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stacked bar
          if (billedTotal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (cashPct > 0)
                      Flexible(flex: cashPct, child: Container(color: const Color(0xFF10B981))),
                    if (upiPct > 0)
                      Flexible(flex: upiPct, child: Container(color: const Color(0xFF8B5CF6))),
                    if (cardPct > 0)
                      Flexible(flex: cardPct, child: Container(color: const Color(0xFF0EA5E9))),
                    if (pendingPct > 0)
                      Flexible(flex: pendingPct, child: Container(color: const Color(0xFFD97706))),
                    if (100 - cashPct - upiPct - cardPct - pendingPct > 0)
                      Flexible(
                        flex: math.max(1, 100 - cashPct - upiPct - cardPct - pendingPct),
                        child: Container(color: const Color(0xFFE2E8F0)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 1. Cash Row
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.money,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            barColor: const Color(0xFF10B981),
            label: 'Cash',
            collectedText: '${_formatCurrency(cash)} collected',
            percent: cashPct,
          ),
          const SizedBox(height: 14),

          // 2. UPI / QR Row
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.qrCode,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFF5F3FF),
            barColor: const Color(0xFF8B5CF6),
            label: 'UPI / QR',
            collectedText: '${_formatCurrency(upi)} collected',
            percent: upiPct,
          ),
          const SizedBox(height: 14),

          if (card > 0) ...[
            _buildPaymentChannelRow(
              icon: PhosphorIconsBold.creditCard,
              iconColor: const Color(0xFF0EA5E9),
              iconBg: const Color(0xFFF0F9FF),
              barColor: const Color(0xFF0EA5E9),
              label: 'Card',
              collectedText: '${_formatCurrency(card)} collected',
              percent: cardPct,
            ),
            const SizedBox(height: 14),
          ],

          // 3. Pending Row - reads "outstanding", not "collected", because
          // this is the one channel where nothing has been handed over.
          _buildPaymentChannelRow(
            icon: PhosphorIconsBold.clockCountdown,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFFFBEB),
            barColor: const Color(0xFFD97706),
            label: 'Pending',
            collectedText: '${_formatCurrency(pending)} outstanding',
            percent: pendingPct,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChannelRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color barColor,
    required String label,
    required String collectedText,
    required int percent,
  }) {
    return Row(
      children: [
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                collectedText,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$percent%',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: barColor,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 54,
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
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenBilling,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsBold.shoppingCart, color: Colors.white, size: 19),
                      SizedBox(width: 9),
                      Text(
                        'Start Billing',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
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
            Expanded(
              child: InkWell(
                onTap: onOpenAttendance,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsRegular.calendarBlank, color: Color(0xFF475467), size: 19),
                      SizedBox(width: 9),
                      Text(
                        'Attendance',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475467),
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

// ─── Arc Gauge Painter ────────────────────────────────────────────────────────

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final bool achieved;

  const _ArcGaugePainter({required this.progress, required this.achieved});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 6;
    const strokeWidth = 7.0;

    final trackPaint = Paint()
      ..color = const Color(0xFFEEF2FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = achieved
          ? const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
            ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
          : const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
            ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

    const startAngle = math.pi * 0.75;
    const sweepMax = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepMax,
      false,
      trackPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepMax * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress || old.achieved != achieved;
}
