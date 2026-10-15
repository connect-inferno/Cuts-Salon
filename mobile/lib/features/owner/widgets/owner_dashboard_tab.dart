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
import '../../auth/auth_provider.dart';
import 'owner_customers_employees_tab.dart' show FollowUp, followUpFor;

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
  final VoidCallback? onOpenDues;
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
    this.onOpenDues,
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
                _buildGreeting(ref, state),
                const SizedBox(height: 14),
                _buildTodaySummary(dashboard, state),
                const SizedBox(height: 18),
                ..._buildSetupChecklist(state),
                ..._buildAttention(state, dashboard),
                const DsSectionLabel('Today'),
                _buildStatsCard(dashboard),
                ..._buildRecentBills(state),
                ..._buildStaffToday(state),
                const SizedBox(height: 18),
                const DsSectionLabel('Money'),
                _buildTargetCard(context, ref, dashboard, state),
                const SizedBox(height: 12),
                _buildPaymentsCard(dashboard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Today ─────────────────────────────────────────────────────────────────

  /// "Good afternoon, Amit" over the salon's name - the first line a person
  /// reads should be about them and their salon, not the word "Home".
  Widget _buildGreeting(WidgetRef ref, AppData state) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = (ref.watch(authControllerProvider).name ?? '').trim().split(' ').first;
    final salon = state.settings?.salonName ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? part : '$part, $name',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppTheme.slateDark, letterSpacing: -0.4),
          ),
          if (salon.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(salon, style: const TextStyle(fontSize: 13, color: AppTheme.slateLight)),
          ],
        ],
      ),
    );
  }

  /// Today's takings, on a white card with a thin navy accent line, and the
  /// two jobs this page is opened for right under the figure.
  Widget _buildTodaySummary(DashboardSummary dashboard, AppData state) {
    final bills = dashboard.todayBillCount;
    final trend = _lastSevenDays(state);
    return DsCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(2)),
              ),
              const Spacer(),
              if (state.branches.length > 1) _buildBranchSelector(state),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Today's revenue", style: TextStyle(fontSize: 13, color: AppTheme.slateLight)),
          const SizedBox(height: 4),
          Text(
            _formatCurrency(dashboard.todaySales),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppTheme.slateDark,
              letterSpacing: -1.2,
              height: 1.15,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          // Wraps rather than truncating - on a phone the bill count was
          // being cut off behind "...".
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDeltaPill(dashboard.todaySales, trend.length >= 2 ? trend[trend.length - 2] : 0),
              Text(
                '${_formatCurrency(dashboard.weekSales)} this week  ·  $bills bill${bills == 1 ? '' : 's'} today',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Last 7 days' takings, today last - the shape of the week at a
          // glance, under the one number that matters most.
          SizedBox(
            height: 44,
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter(trend)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_weekdayShort(6), style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
              const Spacer(),
              const Text('Today', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenBilling,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(PhosphorIconsBold.receipt, size: 17),
                  label: const Text('New bill'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenAttendance,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(PhosphorIconsRegular.calendarCheck, size: 17),
                  label: const Text('Attendance'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Takings for each of the last 7 days (oldest first, today last), from
  /// the loaded bills, scoped to the selected branch like the rest of Home.
  List<double> _lastSevenDays(AppData state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final totals = List<double>.filled(7, 0);
    for (final b in state.bills) {
      final at = b.createdAt;
      if (at == null) continue;
      if (selectedBranchId != null && b.branchId != selectedBranchId) continue;
      final day = DateTime(at.year, at.month, at.day);
      final ago = today.difference(day).inDays;
      if (ago >= 0 && ago < 7) totals[6 - ago] += b.finalAmount;
    }
    return totals;
  }

  String _weekdayShort(int daysAgo) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[DateTime.now().subtract(Duration(days: daysAgo)).weekday - 1];
  }

  /// "+₹150 vs yesterday" in green, or the fall in red - how today compares
  /// is the first question after "how much".
  Widget _buildDeltaPill(double today, double yesterday) {
    final diff = today - yesterday;
    final up = diff >= 0;
    final color = diff == 0 ? AppTheme.slateLight : (up ? AppTheme.accentGreen : AppTheme.accentRed);
    final label = diff == 0
        ? 'Same as yesterday'
        : '${up ? '+' : '-'}${_formatCurrency(diff.abs())} vs yesterday';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (diff != 0) ...[
            Icon(up ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
            const SizedBox(width: 4),
            const Icon(PhosphorIconsRegular.caretDown, size: 12, color: AppTheme.primaryBlue),
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

  /// Four figures in one card, split by hairlines - compact tiles with the
  /// icon beside the number, so the card is a glance, not a screenful.
  Widget _buildStatsCard(DashboardSummary dashboard) {
    final avgTicket = dashboard.todayBillCount > 0 ? dashboard.todaySales / dashboard.todayBillCount : 0.0;
    final lowStock = dashboard.lowStockItemCount;
    const vDivider = VerticalDivider(width: 1, thickness: 1, color: AppTheme.borderSubtle);
    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.users,
                    tint: AppTheme.accentBlue,
                    tintBg: AppTheme.accentBlueBg,
                    label: 'Clients',
                    value: '${dashboard.todayCustomersCount}',
                    onTap: onOpenClients,
                  ),
                ),
                vDivider,
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.receipt,
                    tint: AppTheme.accentViolet,
                    tintBg: AppTheme.accentVioletBg,
                    label: 'Bills',
                    value: '${dashboard.todayBillCount}',
                    caption: avgTicket > 0 ? 'avg ${_formatCurrency(avgTicket)}' : null,
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
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.userCheck,
                    tint: AppTheme.accentOrange,
                    tintBg: AppTheme.accentOrangeBg,
                    label: 'Staff in',
                    value: '${dashboard.todayAttendanceCount}',
                    onTap: onOpenAttendance,
                  ),
                ),
                vDivider,
                Expanded(
                  child: DsStatTile(
                    icon: PhosphorIconsRegular.package,
                    tint: AppTheme.accentRose,
                    tintBg: AppTheme.accentRoseBg,
                    label: 'Low stock',
                    value: '$lowStock',
                    tone: lowStock > 0 ? AppTheme.accentRed : null,
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

  // ─── Needs attention ──────────────────────────────────────────────────────

  /// The things waiting on the owner, each one tap from where it's dealt
  /// with. Hidden entirely on a day with nothing waiting.
  List<Widget> _buildAttention(AppData state, DashboardSummary dashboard) {
    final requests = state.pendingDiscountCount + state.pendingPaymentRequestCount;
    final owing = state.bills.where((b) => b.amountDue > 0).toList();
    final dueTotal = owing.fold<double>(0, (sum, b) => sum + b.amountDue);
    final dueClients = owing.map((b) => b.customerId).toSet().length;
    final now = DateTime.now();
    final overdue = state.customers.where((c) => followUpFor(c, now) == FollowUp.overdue).length;
    final lowStock = dashboard.lowStockItemCount;

    final rows = <Widget>[
      if (requests > 0)
        _attentionRow(PhosphorIconsRegular.bellRinging, '$requests request${requests == 1 ? '' : 's'} waiting',
            'Discounts and payments from staff', AppTheme.accentAmber, onOpenNotifications),
      if (dueTotal > 0)
        _attentionRow(PhosphorIconsRegular.handCoins, '${_formatCurrency(dueTotal)} to collect',
            'Owed by $dueClients client${dueClients == 1 ? '' : 's'}', AppTheme.accentAmber, onOpenDues),
      if (lowStock > 0)
        _attentionRow(PhosphorIconsRegular.package, '$lowStock product${lowStock == 1 ? '' : 's'} low on stock',
            'Restock before they run out', AppTheme.accentRed, onOpenServices),
      if (overdue > 0)
        _attentionRow(PhosphorIconsRegular.clockCounterClockwise, '$overdue client${overdue == 1 ? '' : 's'} due for a visit',
            'No visit in 21 days or more', AppTheme.primaryBlue, onOpenClients),
    ];
    if (rows.isEmpty) return const [];
    return [
      const DsSectionLabel('Needs attention'),
      DsCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 64, color: AppTheme.borderSubtle),
              rows[i],
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  Widget _attentionRow(IconData icon, String title, String subtitle, Color tone, VoidCallback? onTap) {
    return DsListRow(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: tone.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: tone),
      ),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  // ─── Recent bills ─────────────────────────────────────────────────────────

  List<Widget> _buildRecentBills(AppData state) {
    final bills = [...state.bills]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final recent = bills.take(4).toList();
    if (recent.isEmpty) return const [];
    return [
      const SizedBox(height: 18),
      DsSectionLabel('Recent bills', trailing: _seeAll('All bills', onOpenBilling)),
      DsCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < recent.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 66, color: AppTheme.borderSubtle),
              _billRow(recent[i]),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _billRow(Bill bill) {
    final name = (bill.customerName?.isNotEmpty ?? false) ? bill.customerName! : 'Walk-in';
    final services = bill.items.length;
    return DsListRow(
      leading: DsAvatar(name),
      title: name,
      subtitle: '${bill.invoiceNumber}  ·  ${_timeLabel(bill.createdAt)}'
          '${services > 0 ? '  ·  $services item${services == 1 ? '' : 's'}' : ''}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatCurrency(bill.finalAmount),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 3),
          bill.isFullyPaid
              ? const DsPill('Paid', color: AppTheme.accentGreen)
              : DsPill('Due ${_formatCurrency(bill.amountDue)}', color: AppTheme.accentAmber),
        ],
      ),
    );
  }

  // ─── Staff today ──────────────────────────────────────────────────────────

  List<Widget> _buildStaffToday(AppData state) {
    final staff = state.employees.where((e) => e.active).toList();
    if (staff.isEmpty) return const [];
    final now = DateTime.now();
    AttendanceRecord? todayFor(String id) {
      for (final a in state.attendance) {
        final d = a.date;
        if (a.employeeId == id && d != null && d.year == now.year && d.month == now.month && d.day == now.day) return a;
      }
      return null;
    }

    return [
      const SizedBox(height: 18),
      DsSectionLabel('Staff today', trailing: _seeAll('Attendance', onOpenAttendance)),
      DsCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < staff.length && i < 6; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 66, color: AppTheme.borderSubtle),
              () {
                final emp = staff[i];
                final rec = todayFor(emp.id);
                final pill = switch (rec?.status) {
                  'PRESENT' => DsPill(rec?.clockIn != null ? 'In since ${_timeLabel(rec!.clockIn)}' : 'Present',
                      color: AppTheme.accentGreen),
                  'LATE' => DsPill(rec?.clockIn != null ? 'Late · ${_timeLabel(rec!.clockIn)}' : 'Late',
                      color: AppTheme.accentAmber),
                  'ABSENT' => const DsPill('Absent', color: AppTheme.accentRed),
                  _ => const DsPill('Not in yet'),
                };
                return DsListRow(
                  leading: DsAvatar(emp.name),
                  title: emp.name,
                  subtitle: emp.roleTitle.isNotEmpty ? emp.roleTitle : null,
                  trailing: pill,
                );
              }(),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _seeAll(String label, VoidCallback? onTap) {
    if (onTap == null) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue)),
      ),
    );
  }

  String _timeLabel(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
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
                  labelText: 'Target (₹)',
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
          DsValueRow(label: 'Cash', value: _formatCurrency(cash), dot: AppTheme.primaryBlue),
          DsValueRow(label: 'UPI', value: _formatCurrency(upi), dot: const Color(0xFF7B93B4)),
          if (card > 0) DsValueRow(label: 'Card', value: _formatCurrency(card), dot: const Color(0xFFC3D0E2)),
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

/// A small area sparkline: navy line, soft navy fill fading down, a dot on
/// today's value. Draws a flat baseline when every day is zero.
class _SparklinePainter extends CustomPainter {
  final List<double> values;

  _SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;
    final dx = n > 1 ? size.width / (n - 1) : size.width;
    Offset point(int i) {
      final y = maxV <= 0 ? size.height - 2 : size.height - 4 - (values[i] / maxV) * (size.height - 10);
      return Offset(i * dx, y);
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < n; i++) {
      final p0 = point(i - 1);
      final p1 = point(i);
      final mid = (p0.dx + p1.dx) / 2;
      line.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryBlue.withValues(alpha: 0.14), AppTheme.primaryBlue.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.primaryBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    final last = point(n - 1);
    canvas.drawCircle(last, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 3, Paint()..color = AppTheme.primaryBlue);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
