import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data.dart';
import '../../../data/app_data_provider.dart';
import '../../../data/expenses_provider.dart';
import '../../../data/insights.dart';
import '../../../data/insights_provider.dart';
import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../data/report_summary.dart';
import '../../../data/salary_provider.dart';
import '../../../router.dart';
import '../../../theme.dart';
import '../../../widgets/async_state_views.dart';
import '../../../widgets/csv_export.dart';
import '../../../widgets/ds.dart';
import 'client_retention_report.dart';
import 'insight_charts.dart';
import 'owner_customers_employees_tab.dart' show OwnerCustomerDetailPage;
import 'owner_insights.dart';

/// Reports: one month at a time, in five sections - Takings, Profit, Team &
/// services, Clients, Stock. Each section opens with its answer in one
/// sentence, then the chart and the list behind it.
///
/// Every figure for a month comes from that month's monthlyStats rollup
/// (data/insights.dart), never from the loaded bills, which are capped at
/// the newest 300 - that is what made the old page's numbers disagree.
/// Things that only exist "as of now" (who to call back, money owed, stock)
/// say so.
class OwnerReportsTab extends ConsumerStatefulWidget {
  final VoidCallback? onOpenNotifications;

  /// New bill for a client opened from the Clients section.
  final ValueChanged<Customer>? onStartBill;

  const OwnerReportsTab({super.key, this.onOpenNotifications, this.onStartBill});

  @override
  ConsumerState<OwnerReportsTab> createState() => _OwnerReportsTabState();
}

enum ReportSection {
  takings('Takings', PhosphorIconsRegular.currencyInr),
  profit('Profit', PhosphorIconsRegular.scales),
  team('Team & services', PhosphorIconsRegular.usersThree),
  clients('Clients', PhosphorIconsRegular.addressBook),
  stock('Stock', PhosphorIconsRegular.package);

  const ReportSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

/// How far back the month stepper goes: the twelve months insightsProvider
/// loads (plus the one before the oldest, for its comparison).
const _kMonthsBack = 11;

class _OwnerReportsTabState extends ConsumerState<OwnerReportsTab> {
  late DateTime _month;
  ReportSection _section = ReportSection.takings;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  DateTime get _thisMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime get _oldestMonth => DateTime(_thisMonth.year, _thisMonth.month - _kMonthsBack, 1);
  DateTime get _prevMonth => DateTime(_month.year, _month.month - 1, 1);

  void _stepMonth(int by) => setState(() => _month = DateTime(_month.year, _month.month + by, 1));

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(appDataProvider);
    return asyncData.when(
      loading: () => const AppLoadingView(),
      error: (err, st) => AppErrorView(error: err, onRetry: () => ref.read(appDataProvider.notifier).refresh()),
      data: (state) {
        final insightsAsync = ref.watch(insightsProvider);
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final insights = insightsAsync.valueOrNull;
          final summary = insights == null ? null : _Summary.of(state, insights, _month, _prevMonth, ref);

          Widget sectionBody() {
            if (insightsAsync.hasError && insights == null) {
              return _NotAvailable(error: insightsAsync.error!, onRetry: () => ref.invalidate(insightsProvider));
            }
            if (insights == null || summary == null) return const _SectionSkeleton();
            return _sectionContent(context, state, insights, summary);
          }

          final banner = insights != null && insights.needsBackfill(oldestLoadedBill(state))
              ? const Padding(padding: EdgeInsets.only(bottom: 14), child: InsightsBackfillBanner())
              : const SizedBox.shrink();

          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _monthStepper(),
                        const SizedBox(height: 14),
                        _SectionIndex(
                          selected: _section,
                          answers: summary?.indexAnswers,
                          onSelect: (s) => setState(() => _section = s),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [banner, sectionBody()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _monthStepper(),
              const SizedBox(height: 12),
              _SectionChips(selected: _section, onSelect: (s) => setState(() => _section = s)),
              const SizedBox(height: 16),
              banner,
              sectionBody(),
            ],
          );
        });
      },
    );
  }

  Widget _monthStepper() {
    final canBack = _month.isAfter(_oldestMonth);
    final canForward = _month.isBefore(_thisMonth);
    final isThis = !_month.isBefore(_thisMonth);
    return DsCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('reportsPrevMonth'),
            tooltip: 'Previous month',
            onPressed: canBack ? () => _stepMonth(-1) : null,
            icon: const Icon(PhosphorIconsBold.caretLeft, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${reportMonthName(_month)} ${_month.year}',
                  key: const Key('reportsMonth'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                ),
                Text(
                  isThis ? 'This month, so far' : 'Compared with ${reportMonthName(_prevMonth)}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.slateLight),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('reportsNextMonth'),
            tooltip: 'Next month',
            onPressed: canForward ? () => _stepMonth(1) : null,
            icon: const Icon(PhosphorIconsBold.caretRight, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _sectionContent(BuildContext context, AppData state, InsightsData insights, _Summary s) {
    void openClient(Customer c) => pushAppRoute(
          context,
          OwnerCustomerDetailPage(customerId: c.id, onStartBill: widget.onStartBill),
        );
    return switch (_section) {
      ReportSection.takings => _TakingsSection(s: s, state: state, insights: insights, month: _month,
          onExport: () => _exportMonth(context, state)),
      ReportSection.profit => _ProfitSection(s: s, insights: insights, month: _month),
      ReportSection.team => _TeamSection(s: s, state: state, month: _month),
      ReportSection.clients => _ClientsSection(s: s, state: state, onOpenClient: openClient),
      ReportSection.stock => _StockSection(s: s),
    };
  }

  /// The month's bills as a spreadsheet, one row per line. From the bills
  /// on this device (the newest 300), so an older month can be partial - the
  /// message says so.
  Future<void> _exportMonth(BuildContext context, AppData state) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = DateTime(_month.year, _month.month + 1, 1);
    final bills = state.bills
        .where((b) => b.createdAt != null && !b.createdAt!.isBefore(_month) && b.createdAt!.isBefore(next))
        .toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    if (bills.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('No bills on this device for that month.')));
      return;
    }
    final branchNames = {for (final b in state.branches) b.id: b.name};
    final rows = <List<Object?>>[
      ['Invoice', 'Date', 'Branch', 'Client', 'Type', 'Item', 'Qty', 'Unit price', 'Line discount', 'Line total',
        'Performed by', 'Commission', 'Bill total', 'Paid', 'Balance', 'Payment method'],
    ];
    for (final bill in bills) {
      final d = bill.createdAt!;
      final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final head = [bill.invoiceNumber, date, branchNames[bill.branchId] ?? bill.branchId, bill.customerName ?? ''];
      final tail = [bill.finalAmount.toStringAsFixed(2), bill.amountPaid.toStringAsFixed(2),
        bill.amountDue.toStringAsFixed(2), paymentMethodLabel(bill.paymentMethod)];
      if (bill.items.isEmpty) {
        rows.add([...head, '', '', '', '', '', '', '', '', ...tail]);
      }
      for (final item in bill.items) {
        rows.add([
          ...head,
          item.type == 'SERVICE' ? 'Service' : 'Product',
          item.serviceName ?? item.productName ?? '',
          item.quantity,
          item.unitPrice.toStringAsFixed(2),
          item.discountAmount.toStringAsFixed(2),
          (item.unitPrice * item.quantity - item.discountAmount).toStringAsFixed(2),
          item.employeeName ?? state.employeeById(item.employeeId)?.name ?? '',
          item.calculatedCommission.toStringAsFixed(2),
          ...tail,
        ]);
      }
    }
    final oldest = oldestLoadedBill(state);
    final partial = oldest != null && oldest.isAfter(_month);
    final filename = 'bills-${_month.year}-${_month.month.toString().padLeft(2, '0')}.csv';
    try {
      final result = await exportCsv(filename, toCsv(rows));
      if (!mounted) return;
      final what = switch (result) {
        CsvExportResult.downloaded => 'Downloaded $filename',
        CsvExportResult.copiedToClipboard => 'Copied as CSV - paste into a spreadsheet',
        CsvExportResult.shared => '$filename ready - save it or send it from the share menu',
      };
      messenger.showSnackBar(SnackBar(
        content: Text(partial ? '$what. Only the bills on this device - older ones from that month are not included.' : what),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.accentRed));
    }
  }
}

// ---------------------------------------------------------------------------
// The month's figures, worked out once so the index and the sections agree
// ---------------------------------------------------------------------------

class _Summary {
  final RollupStats cur;
  final RollupStats prev;
  final DateTime month;
  final DateTime prevMonth;
  final List<StaffMonth> staff;
  final List<ServiceMonth> services;
  final ClientRetentionStats retention;
  final double owed;
  final StockInsights stock;
  final MonthPnl? pnl;
  final MonthPnl? prevPnl;
  final bool pnlLoading;

  _Summary({
    required this.cur,
    required this.prev,
    required this.month,
    required this.prevMonth,
    required this.staff,
    required this.services,
    required this.retention,
    required this.owed,
    required this.stock,
    required this.pnl,
    required this.prevPnl,
    required this.pnlLoading,
  });

  static _Summary of(AppData state, InsightsData insights, DateTime month, DateTime prevMonth, WidgetRef ref) {
    final now = DateTime.now();
    final cur = insights.month(month);
    final expenses = ref.watch(expensesProvider);
    final salaries = ref.watch(salaryRecordsProvider);
    final pnlLoading = expenses.isLoading || salaries.isLoading;
    List<MonthPnl>? pnl;
    if (!pnlLoading) {
      pnl = computePnl(
        months: [prevMonth, month],
        rollups: insights.months,
        expenses: expenses.valueOrNull ?? const [],
        salaries: salaries.valueOrNull ?? const [],
      );
    }
    return _Summary(
      cur: cur,
      prev: insights.month(prevMonth),
      month: month,
      prevMonth: prevMonth,
      staff: computeStaffMonth(
        employees: state.employees,
        attendance: state.attendance,
        month: cur,
        monthStartDate: month,
      ),
      services: topServices(cur, {for (final s in state.services) s.id: s.name}),
      retention: computeRetention(state.customers, now),
      owed: state.customers.fold<double>(0, (s, c) => s + c.outstandingBalance),
      stock: computeStockInsights(state.inventory, state.bills, now),
      pnl: pnl?.last,
      prevPnl: pnl?.first,
      pnlLoading: pnlLoading,
    );
  }

  int get runningOut => stock.runningOut.length;

  Map<ReportSection, String> get indexAnswers => {
        ReportSection.takings: cur.sales > 0 ? '${formatInr(cur.sales)} taken' : 'No takings yet',
        ReportSection.profit: pnlLoading || pnl == null
            ? 'Working it out...'
            : pnl!.profit < 0
                ? 'Loss of ${formatInr(-pnl!.profit)}'
                : '${formatInr(pnl!.profit)} left after costs',
        ReportSection.team: staff.isNotEmpty && staff.first.sales > 0
            ? '${staff.first.employee.name} earned most'
            : 'No staff takings yet',
        ReportSection.clients: '${retention.toContact} to call back',
        ReportSection.stock: runningOut > 0 ? '$runningOut running out' : 'Nothing running out',
      };
}

// ---------------------------------------------------------------------------
// Navigation: index (wide) and chips (phone)
// ---------------------------------------------------------------------------

class _SectionIndex extends StatelessWidget {
  final ReportSection selected;
  final Map<ReportSection, String>? answers;
  final ValueChanged<ReportSection> onSelect;
  const _SectionIndex({required this.selected, required this.answers, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          for (final s in ReportSection.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Material(
                color: s == selected ? AppTheme.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: Key('reportsIndex_${s.name}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(s),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    child: Row(
                      children: [
                        Icon(s.icon, size: 18, color: s == selected ? AppTheme.primaryBlue : AppTheme.slateLight),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: s == selected ? AppTheme.primaryBlue : AppTheme.slateDark,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                answers?[s] ?? ' ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppTheme.slateLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionChips extends StatelessWidget {
  final ReportSection selected;
  final ValueChanged<ReportSection> onSelect;
  const _SectionChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in ReportSection.values) ...[
            if (s.index > 0) const SizedBox(width: 8),
            Material(
              color: s == selected ? AppTheme.primaryBlue : AppTheme.cardBg,
              shape: StadiumBorder(side: BorderSide(color: s == selected ? AppTheme.primaryBlue : AppTheme.borderStrong)),
              child: InkWell(
                key: Key('reportsChip_${s.name}'),
                customBorder: const StadiumBorder(),
                onTap: () => onSelect(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    s.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s == selected ? Colors.white : AppTheme.slateDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section pieces
// ---------------------------------------------------------------------------

/// The section's answer: its heading, the one figure that answers it, and
/// one line of context. Sits on the page, not in a card.
class _Answer extends StatelessWidget {
  final String heading;
  final String figure;
  final Color? figureColor;
  final String? change;
  final int direction;
  final String? note;
  const _Answer({
    required this.heading,
    required this.figure,
    this.figureColor,
    this.change,
    this.direction = 0,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.slateMedium)),
          const SizedBox(height: 4),
          Text(
            figure,
            key: const Key('reportsAnswer'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.15,
              color: figureColor ?? AppTheme.slateDark,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (direction != 0) ...[
                  Icon(
                    direction > 0 ? PhosphorIconsBold.arrowUpRight : PhosphorIconsBold.arrowDownRight,
                    size: 14,
                    color: AppTheme.slateMedium,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(change!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.slateMedium)),
                ),
              ],
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: const TextStyle(fontSize: 12.5, color: AppTheme.slateLight, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

const _gap = SizedBox(height: 14);

String _plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

List<DateTime> _sixMonthsTo(DateTime m) => [for (var i = 5; i >= 0; i--) DateTime(m.year, m.month - i, 1)];

// ---------------------------------------------------------------------------
// Takings
// ---------------------------------------------------------------------------

class _TakingsSection extends StatelessWidget {
  final _Summary s;
  final AppData state;
  final InsightsData insights;
  final DateTime month;
  final VoidCallback onExport;
  const _TakingsSection({required this.s, required this.state, required this.insights, required this.month, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final cur = s.cur, prev = s.prev;
    final pace = onPaceFor(cur.sales, month, DateTime.now());
    final months = _sixMonthsTo(month);
    final avg = cur.billCount == 0 ? 0.0 : cur.sales / cur.billCount;
    final prevAvg = prev.billCount == 0 ? 0.0 : prev.sales / prev.billCount;
    final branches = cur.group('byBranch');
    final branchNames = {for (final b in state.branches) b.id: b.name};
    final gross = cur.serviceSales + cur.productSales;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Answer(
          heading: 'Takings in ${reportMonthName(month)}',
          figure: formatInr(cur.sales),
          change: changeVsLastMonth(cur.sales, prev.sales, s.prevMonth),
          direction: changeDirection(cur.sales, prev.sales),
          note: pace == null ? null : 'On pace for about ${formatInr(pace.roundToDouble())} by the end of the month.',
        ),
        DsCard(
          child: InsightFigures([
            ('Bills', '${cur.billCount}', '${prev.billCount} in ${reportMonthShort(s.prevMonth)}'),
            ('Average bill', formatInr(avg), '${formatInr(prevAvg)} in ${reportMonthShort(s.prevMonth)}'),
            ('New clients', '${cur.newClients}', '${prev.newClients} in ${reportMonthShort(s.prevMonth)}'),
          ]),
        ),
        _gap,
        InsightCard(
          title: 'Takings by month',
          subtitle: 'Six months to ${reportMonthName(month)}. Tap a bar for its total.',
          child: months.every((m) => insights.month(m).sales <= 0)
              ? const InsightEmpty('No takings in these six months yet.')
              : ColumnChart(
            key: ValueKey('takings-${monthKey(month)}'),
            labels: [for (final m in months) reportMonthShort(m)],
            series: [ColumnSeries('Takings', kChartNavy, [for (final m in months) insights.month(m).sales])],
            describe: (i) => formatInr(insights.month(months[i]).sales),
          ),
        ),
        _gap,
        InsightCard(
          title: 'Services and products',
          subtitle: 'What the takings were made of, before GST',
          child: gross <= 0
              ? const InsightEmpty('Shows once bills are raised in this month.')
              : Column(
                  children: [
                    HBarList([
                      HBarItem('Services', cur.serviceSales, formatInr(cur.serviceSales),
                          caption: _plural(cur['serviceCount'].round(), 'service'), color: kChartNavy),
                      HBarItem('Products', cur.productSales, formatInr(cur.productSales),
                          caption: _plural(cur['productUnits'].round(), 'item'), color: kChartNavySoft),
                    ]),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.borderSubtle),
                    const SizedBox(height: 14),
                    InsightFigures([
                      ('Discounts given', formatInr(cur.discount), null),
                      ('GST collected', formatInr(cur.tax), 'owed to the government'),
                    ]),
                  ],
                ),
        ),
        _gap,
        InsightCard(
          title: 'Busiest times',
          subtitle: 'Bills by day and hour in ${reportMonthName(month)}. Darker means busier.',
          child: cur.group('slots').isEmpty
              ? const InsightEmpty('Shows once bills are raised in this month.')
              : BusyHoursHeatmap(slots: cur.group('slots')),
        ),
        if (state.branches.length > 1) ...[
          _gap,
          InsightCard(
            title: 'By branch',
            subtitle: 'Takings at each branch in ${reportMonthName(month)}',
            child: branches.isEmpty
                ? const InsightEmpty('No branch takings this month.')
                : HBarList([
                    for (final e in (branches.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                      HBarItem(branchNames[e.key] ?? 'Closed branch', e.value, formatInr(e.value), color: kChartNavy),
                  ]),
          ),
        ],
        _gap,
        DsCard(
          onTap: onExport,
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.downloadSimple, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Download ${reportMonthName(month)} bills',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                    const Text('Spreadsheet (CSV), one row per item',
                        style: TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.caretRight, size: 15, color: AppTheme.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profit
// ---------------------------------------------------------------------------

class _ProfitSection extends ConsumerWidget {
  final _Summary s;
  final InsightsData insights;
  final DateTime month;
  const _ProfitSection({required this.s, required this.insights, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = s.pnl;
    if (s.pnlLoading || p == null) return const _SectionSkeleton();
    final prev = s.prevPnl!;
    final loss = p.profit < 0;
    final months = _sixMonthsTo(month);
    final six = computePnl(
      months: months,
      rollups: insights.months,
      expenses: ref.watch(expensesProvider).valueOrNull ?? const [],
      salaries: ref.watch(salaryRecordsProvider).valueOrNull ?? const [],
    );

    Widget line(String label, double v, {String? note, bool minus = true, bool total = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: total ? 8 : 6),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label),
                    if (note != null) TextSpan(text: '  $note', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                  ]),
                  style: TextStyle(
                    fontSize: total ? 14.5 : 13.5,
                    fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                    color: total ? AppTheme.slateDark : AppTheme.slateMedium,
                  ),
                ),
              ),
              Text(
                '${minus && v > 0 ? '- ' : ''}${formatInr(v.abs())}',
                style: TextStyle(
                  fontSize: total ? 15 : 13.5,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w600,
                  color: total && v < 0 ? AppTheme.accentRed : AppTheme.slateDark,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Answer(
          heading: loss ? 'Loss in ${reportMonthName(month)}' : 'Left after costs in ${reportMonthName(month)}',
          figure: formatInr(p.profit.abs()),
          figureColor: loss ? AppTheme.accentRed : null,
          change: prev.revenue <= 0 && prev.profit == 0
              ? 'Nothing in ${reportMonthName(s.prevMonth)} to compare with'
              : '${formatInr(prev.profit)} in ${reportMonthName(s.prevMonth)}',
          direction: prev.revenue <= 0 ? 0 : (p.profit - prev.profit).sign.toInt(),
          note: p.revenue > 0 && !loss ? 'That is ₹${p.marginPct.round()} of every ₹100 taken, after GST.' : null,
        ),
        DsCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line('Takings', p.revenue, minus: false, note: 'without GST'),
              line('Product cost', p.productCost),
              line('Expenses', p.expenses),
              line('Staff pay', p.payroll, note: p.payrollEstimated ? 'commission so far' : null),
              const Divider(height: 10, color: AppTheme.borderSubtle),
              line(loss ? 'Loss' : 'Profit', p.profit, minus: false, total: true),
              if (p.payrollEstimated)
                const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    "Payroll hasn't been run for this month, so staff pay is only the commission earned so far - "
                    'base salaries are not in yet.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.slateLight),
                  ),
                ),
            ],
          ),
        ),
        _gap,
        InsightCard(
          title: 'Profit by month',
          subtitle: 'Six months to ${reportMonthName(month)}. A loss hangs below the line.',
          child: six.every((m) => m.revenue <= 0 && m.profit == 0)
              ? const InsightEmpty('No takings or costs in these six months yet.')
              : ColumnChart(
            key: ValueKey('profit-${monthKey(month)}'),
            labels: [for (final m in six) reportMonthShort(m.month)],
            series: [ColumnSeries('Profit', kChartNavy, [for (final m in six) m.profit])],
            describe: (i) => '${six[i].profit < 0 ? 'Loss' : 'Profit'} ${formatInr(six[i].profit.abs())}',
          ),
        ),
        _gap,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Product cost uses each product\'s cost price. Expenses and staff pay come from the Expenses and Payroll pages.',
            style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.slateLight),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team & services
// ---------------------------------------------------------------------------

class _TeamSection extends StatelessWidget {
  final _Summary s;
  final AppData state;
  final DateTime month;
  const _TeamSection({required this.s, required this.state, required this.month});

  @override
  Widget build(BuildContext context) {
    final working = s.staff.where((x) => x.sales > 0 || x.daysPresent > 0).toList();
    final top = working.isNotEmpty && working.first.sales > 0 ? working.first : null;
    final services = s.services.take(8).toList();
    final categories = s.cur.group('byCategory');
    final catNames = {for (final c in state.categories) c.id: c.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Answer(
          heading: 'Brought in the most in ${reportMonthName(month)}',
          figure: top == null ? 'No takings yet' : top.employee.name,
          note: top == null
              ? null
              : '${formatInr(top.sales)} from ${_plural(top.billsServed, 'bill')}'
                  // Staff takings are before bill discounts and GST, so a
                  // share over 100% would read as a mistake - left out.
                  '${s.cur.sales > 0 && top.sales <= s.cur.sales ? ' - ${(top.sales / s.cur.sales * 100).round()}% of the month' : ''}.',
        ),
        InsightCard(
          title: 'Team',
          subtitle: 'Takings, bills and days in, ${reportMonthName(month)}',
          child: working.isEmpty
              ? const InsightEmpty('No staff takings or attendance this month yet.')
              : HBarList([
                  for (final x in working)
                    HBarItem(
                      x.employee.name,
                      x.sales,
                      formatInr(x.sales),
                      color: kChartNavy,
                      caption: [
                        _plural(x.billsServed, 'bill'),
                        if (x.billsServed > 0) 'avg ${formatInr(x.avgBill)}',
                        '${_plural(x.daysPresent, 'day')} in',
                        if (x.lateDays > 0) '${x.lateDays} late',
                      ].join(' · '),
                    ),
                ]),
        ),
        _gap,
        InsightCard(
          title: 'Top services',
          subtitle: 'By takings in ${reportMonthName(month)}',
          child: services.isEmpty
              ? InsightEmpty(s.cur.serviceSales > 0
                  ? 'Per-service figures start with bills raised after this update.'
                  : 'No services billed this month yet.')
              : HBarList([
                  for (final x in services)
                    HBarItem(x.name, x.takings, formatInr(x.takings), caption: '${x.count}×', color: kChartNavy),
                ]),
        ),
        _gap,
        InsightCard(
          title: 'By category',
          subtitle: 'Service takings by kind of work, ${reportMonthName(month)}',
          child: categories.isEmpty
              ? const InsightEmpty('No services billed this month yet.')
              : HBarList([
                  for (final e in (categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                    HBarItem(catNames[e.key] ?? 'Uncategorised', e.value, formatInr(e.value), color: kChartNavySoft),
                ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Clients
// ---------------------------------------------------------------------------

class _ClientsSection extends StatelessWidget {
  final _Summary s;
  final AppData state;
  final ValueChanged<Customer> onOpenClient;
  const _ClientsSection({required this.s, required this.state, required this.onOpenClient});

  @override
  Widget build(BuildContext context) {
    final owing = state.customers.where((c) => c.outstandingBalance > 0).toList()
      ..sort((a, b) => b.outstandingBalance.compareTo(a.outstandingBalance));
    final waReady = state.settings?.whatsappReady ?? false;
    final reminders = s.cur['wa.reminders'].round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Answer(
          heading: 'Clients to call back today',
          figure: '${s.retention.toContact}',
          note: s.retention.toContact == 0
              ? 'Everyone who has visited came in within the last 30 days.'
              : 'Not in for 30 days or more. Message or call them from the list below.',
        ),
        DsCard(
          child: InsightFigures([
            ('New clients', '${s.cur.newClients}', 'in ${reportMonthName(s.month)}'),
            ('Bills', '${s.cur.billCount}', 'in ${reportMonthName(s.month)}'),
            if (waReady) ('Back after a reminder', '${s.cur.reminderReturns}', 'of $reminders reminded'),
          ]),
        ),
        if (s.retention.toContact > 0) ...[
          _gap,
          ClientRetentionReport(
            compact: true,
            customers: state.customers,
            now: DateTime.now(),
            salonName: state.settings?.salonName,
            onOpenClient: onOpenClient,
          ),
        ],
        _gap,
        InsightCard(
          title: 'Money owed',
          subtitle: 'Pay-later balances, as of today',
          headline: formatInr(s.owed),
          headlineColor: s.owed > 0 ? AppTheme.accentAmber : null,
          child: owing.isEmpty
              ? const InsightEmpty('Nothing owed - every bill is paid.')
              : Column(
                  children: [
                    for (final c in owing.take(5))
                      DsListRow(
                        leading: DsAvatar(c.name, size: 32),
                        title: c.name,
                        subtitle: c.phone,
                        trailing: Text(
                          formatInr(c.outstandingBalance),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                        ),
                        onTap: () => onOpenClient(c),
                      ),
                    if (owing.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('and ${_plural(owing.length - 5, 'more client')} - see Clients > Dues',
                            style: const TextStyle(fontSize: 12, color: AppTheme.slateLight)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------

class _StockSection extends StatelessWidget {
  final _Summary s;
  const _StockSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final st = s.stock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Answer(
          heading: 'Running out in the next two weeks',
          figure: st.products.isEmpty
              ? 'No products'
              : s.runningOut == 0
                  ? 'Nothing'
                  : _plural(s.runningOut, 'product'),
          note: 'As of today, from sales in the last ${_plural(st.daysCovered, 'day')}.',
        ),
        DsCard(
          child: InsightFigures([
            ('On the shelf', formatInr(st.valueAtCost), 'at cost price'),
            ('If all sold', formatInr(st.valueAtPrice), 'at selling price'),
            ('Profit in stock', formatInr(st.potentialProfit), null),
          ]),
        ),
        _gap,
        StockHealthCard(stock: st),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => FractionallySizedBox(
          widthFactor: w,
          alignment: Alignment.centerLeft,
          child: Container(height: h, decoration: BoxDecoration(color: AppTheme.borderSubtle, borderRadius: BorderRadius.circular(6))),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(0.35, 12),
          const SizedBox(height: 10),
          bar(0.5, 28),
          const SizedBox(height: 10),
          bar(0.4, 12),
          const SizedBox(height: 20),
          Container(height: 160, decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderSubtle))),
        ],
      ),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _NotAvailable({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final code = error is FirebaseException ? (error as FirebaseException).code : '';
    final text = code == 'permission-denied'
        ? "Reports aren't switched on for your salon yet. Ask the Stylux team to update it."
        : "Couldn't load your reports. Check the connection and try again.";
    return DsCard(
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppTheme.slateMedium, height: 1.4))),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
