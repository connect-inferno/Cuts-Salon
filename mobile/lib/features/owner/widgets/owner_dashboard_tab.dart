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
import '../../../widgets/ds.dart';

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
  // Where the setup checklist's steps go (see _buildSetupChecklist).
  final VoidCallback? onOpenServices;
  final VoidCallback? onOpenTeam;
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
    this.onOpenServices,
    this.onOpenTeam,
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
        color: const Color(0xFFFAFAFA),
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
                  tooltip: 'Requests',
                  badgeCount: state.pendingDiscountCount + state.pendingPaymentRequestCount,
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

    // One calm column: today's takings, the two jobs people open this page
    // for, what still needs setting up, then the numbers. The old layout was
    // a purple gradient banner, four cards in four different colours with
    // glowing icon tiles and badges, a ring gauge and a second gradient
    // card - lots of decoration, and the eye had nowhere to land.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.0 + LiquidNavBar.barInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTodaySummary(dashboard, state),
                const SizedBox(height: 16),
                ..._buildSetupChecklist(state),
                _buildStatsCard(dashboard),
                const SizedBox(height: 16),
                _buildTargetCard(context, ref, dashboard, state),
                const SizedBox(height: 16),
                _buildPaymentsCard(dashboard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Today ─────────────────────────────────────────────────────────────────

  /// Today's takings on a solid brand-teal card, with the two jobs this
  /// page is opened for right on it. Flat colour, no gradient, no decorative
  /// circles - the colour alone makes it the first thing you read.
  Widget _buildTodaySummary(DashboardSummary dashboard, AppData state) {
    final bills = dashboard.todayBillCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's revenue",
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.78)),
                ),
              ),
              if (state.branches.length > 1) _buildBranchSelector(state),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(dashboard.todaySales),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatCurrency(dashboard.weekSales)} this week  ·  $bills bill${bills == 1 ? '' : 's'} today',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.78)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenBilling,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryDarker,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(PhosphorIconsBold.receipt, size: 18),
                  label: const Text('New bill', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenAttendance,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(PhosphorIconsRegular.calendarCheck, size: 18),
                  label: const Text('Attendance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelector(AppData state) {
    final selected = state.branches.where((b) => b.id == selectedBranchId);
    final label = selected.isNotEmpty ? selected.first.name : 'All branches';
    return InkWell(
      onTap: onSelectBranch,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretDown, size: 12, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ─── Setup checklist ──────────────────────────────────────────────────────

  /// "Get your salon ready": the four things a salon fresh from Add Salon
  /// needs before the app is useful. A brand-new owner used to land on a
  /// dashboard of zeros with nothing saying where to start. Each step ticks
  /// itself off from the salon's real data, and the card disappears for good
  /// once all four are done - there's nothing to dismiss or store.
  List<Widget> _buildSetupChecklist(AppData state) {
    final settings = state.settings;
    final steps = [
      (
        done: (settings?.phone?.trim().isNotEmpty ?? false) && (settings?.address?.trim().isNotEmpty ?? false),
        title: "Add your salon's phone and address",
        detail: 'They appear on bills',
        onTap: onOpenSettings,
      ),
      (
        done: state.services.isNotEmpty,
        title: 'Add your services and prices',
        detail: 'Haircut, colour, facial...',
        onTap: onOpenServices,
      ),
      (
        done: state.employees.length > 1,
        title: 'Add your staff',
        detail: 'So they can log in, clock in and bill',
        onTap: onOpenTeam,
      ),
      (
        done: state.bills.isNotEmpty,
        title: 'Make your first bill',
        detail: 'Pick a client, tick services, take payment',
        onTap: onOpenBilling,
      ),
    ];
    final doneCount = steps.where((s) => s.done).length;
    if (doneCount == steps.length) return const [];

    return [
      DsCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsSectionTitle('Get your salon ready', actionLabel: '$doneCount of ${steps.length}'),
            const SizedBox(height: 10),
            DsProgressBar(value: doneCount / steps.length),
            const SizedBox(height: 6),
            for (final step in steps)
              InkWell(
                onTap: step.done ? null : step.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        step.done ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                        size: 20,
                        color: step.done ? AppTheme.accentGreen : AppTheme.borderStrong,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: step.done ? AppTheme.textMuted : AppTheme.slateDark,
                              ),
                            ),
                            if (!step.done)
                              Text(step.detail, style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                          ],
                        ),
                      ),
                      if (!step.done)
                        const Icon(PhosphorIconsRegular.caretRight, size: 14, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  // ─── Numbers ──────────────────────────────────────────────────────────────

  /// Four figures in one card, split by hairlines - instead of four cards
  /// that each wore their own colour, icon tile and badge.
  Widget _buildStatsCard(DashboardSummary dashboard) {
    final avgTicket = dashboard.todayBillCount > 0 ? dashboard.todaySales / dashboard.todayBillCount : 0.0;
    final lowStock = dashboard.lowStockItemCount;
    const divider = VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle);
    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DsStat(
                    icon: PhosphorIconsRegular.users,
                    label: 'Clients today',
                    value: '${dashboard.todayCustomersCount}',
                    onTap: onOpenClients,
                  ),
                ),
                divider,
                Expanded(
                  child: DsStat(
                    icon: PhosphorIconsRegular.receipt,
                    tint: AppTheme.tintBlue,
                    tintBg: AppTheme.tintBlueBg,
                    label: 'Bills today',
                    value: '${dashboard.todayBillCount}',
                    caption: avgTicket > 0 ? 'Avg ${_formatCurrency(avgTicket)}' : null,
                    onTap: onOpenBilling,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DsStat(
                    icon: PhosphorIconsRegular.userCheck,
                    tint: AppTheme.tintAmber,
                    tintBg: AppTheme.tintAmberBg,
                    label: 'Staff in',
                    value: '${dashboard.todayAttendanceCount}',
                    onTap: onOpenAttendance,
                  ),
                ),
                divider,
                Expanded(
                  child: DsStat(
                    icon: PhosphorIconsRegular.package,
                    tint: AppTheme.tintRose,
                    tintBg: AppTheme.tintRoseBg,
                    label: 'Low stock',
                    value: '$lowStock',
                    // Red only when something actually is low.
                    tone: lowStock > 0 ? AppTheme.accentRed : null,
                    caption: lowStock > 0 ? 'Needs restocking' : 'All stocked',
                    onTap: onOpenServices ?? onOpenReports,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0A0A0A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What the salon aims to take in a day. Leave it empty to go '
                'back to showing the running daily average instead.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF71717A), height: 1.4),
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

  Widget _buildTargetCard(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary dashboard,
    AppData state,
  ) {
    final actual = dashboard.todaySales;
    final target = state.settings?.dailyRevenueTarget ?? 0;

    // No target set: say so and offer to set one. This used to fall back to
    // "this month's daily average" and draw progress against it, so a salon
    // with no goal was told "Target reached" on almost any normal day.
    if (target <= 0) {
      return DsCard(
        onTap: () => _showDailyTargetDialog(context, ref, target),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily target', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
                  SizedBox(height: 2),
                  Text('Set a goal to track each day against', style: TextStyle(fontSize: 12.5, color: AppTheme.slateLight)),
                ],
              ),
            ),
            const Text('Set target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateDark)),
            const SizedBox(width: 2),
            const Icon(PhosphorIconsRegular.caretRight, size: 14, color: AppTheme.slateDark),
          ],
        ),
      );
    }

    final progress = (actual / target).clamp(0.0, 1.0);
    final remaining = (target - actual).clamp(0.0, double.infinity);
    final isAchieved = actual >= target;

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionTitle(
            'Daily target',
            actionLabel: 'Edit',
            onAction: () => _showDailyTargetDialog(context, ref, target),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: _formatCurrency(actual),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.slateDark, letterSpacing: -0.4),
                ),
                TextSpan(
                  text: '  of ${_formatCurrency(target)}',
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DsProgressBar(value: progress),
          const SizedBox(height: 8),
          Text(
            isAchieved ? 'Target reached' : '${_formatCurrency(remaining)} to go',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isAchieved ? FontWeight.w600 : FontWeight.w400,
              color: isAchieved ? AppTheme.accentGreen : AppTheme.slateLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsCard(DashboardSummary dashboard) {
    final cash = dashboard.todayCash;
    final upi = dashboard.todayUpi;
    // Card isn't offered at checkout any more, but a pay-later balance can
    // still be settled by card (Clients > Pending > Collect), so its row
    // shows on a day that actually has some.
    final card = dashboard.todayCard;
    // Billed today but not handed over - money owed, so it stays out of
    // the collected total.
    final pending = dashboard.todayOutstanding;
    final collected = cash + upi + card;

    return DsCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DsSectionTitle('Payments today'),
          const SizedBox(height: 6),
          DsValueRow(label: 'Cash', value: _formatCurrency(cash), dot: AppTheme.accentGreen),
          DsValueRow(label: 'UPI', value: _formatCurrency(upi), dot: AppTheme.tintBlue),
          if (card > 0) DsValueRow(label: 'Card', value: _formatCurrency(card), dot: AppTheme.tintTeal),
          const Divider(height: 12, color: AppTheme.borderSubtle),
          DsValueRow(label: 'Collected', value: _formatCurrency(collected), emphasise: true),
          DsValueRow(
            dot: AppTheme.accentAmber,
            label: 'Still to collect',
            value: _formatCurrency(pending),
            valueColor: pending > 0 ? AppTheme.accentAmber : AppTheme.slateLight,
          ),
        ],
      ),
    );
  }
}
