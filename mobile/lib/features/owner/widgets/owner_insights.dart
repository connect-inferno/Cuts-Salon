import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/app_data.dart';
import '../../../data/expenses_provider.dart';
import '../../../data/insights.dart';
import '../../../data/insights_provider.dart';
import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../data/salary_provider.dart';
import '../../../theme.dart';
import '../../../widgets/ds.dart';
import 'insight_charts.dart';

/// Reports' insight cards. Each takes what it needs from AppData (loaded at
/// sign-in, no reads) and/or [InsightsData] (the rollup docs, ~45 reads when
/// Reports opens) - see data/insights.dart for how every figure is made.

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _monthLabel(DateTime m) => _kMonths[m.month - 1];
String _pct(double v) => '${v.isNaN ? 0 : v.round()}%';

/// Shown when months before this version's rollups can still be filled in
/// from the bills. One tap, once per salon.
class InsightsBackfillBanner extends ConsumerStatefulWidget {
  const InsightsBackfillBanner({super.key});

  @override
  ConsumerState<InsightsBackfillBanner> createState() => _InsightsBackfillBannerState();
}

class _InsightsBackfillBannerState extends ConsumerState<InsightsBackfillBanner> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(insightsProvider.notifier).backfill();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primarySoft),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add your past months',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                const SizedBox(height: 2),
                Text(
                  _error ?? 'Charts start from your newest bills. Add the last 12 months once so trends and profit are complete.',
                  style: TextStyle(fontSize: 11.5, color: _error != null ? AppTheme.accentRed : AppTheme.slateMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _busy ? null : _run,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview / Revenue
// ---------------------------------------------------------------------------

class BusyHoursCard extends StatelessWidget {
  final RollupStats window;
  final String periodLabel;
  final String? scopeNote;
  const BusyHoursCard({super.key, required this.window, required this.periodLabel, this.scopeNote});

  @override
  Widget build(BuildContext context) {
    return InsightCard(
      title: 'Busy hours',
      subtitle: 'Bills by day and hour, $periodLabel. Plan shifts around the dark squares.',
      scopeNote: scopeNote,
      child: BusyHoursHeatmap(slots: window.group('slots')),
    );
  }
}

/// Profit and loss per month: takings without GST, minus product cost,
/// expenses and payroll. Expenses and salary slips come from the providers
/// the Expenses and Payroll screens already use.
class ProfitLossCard extends ConsumerStatefulWidget {
  final List<DateTime> months;
  final InsightsData insights;
  const ProfitLossCard({super.key, required this.months, required this.insights});

  @override
  ConsumerState<ProfitLossCard> createState() => _ProfitLossCardState();
}

class _ProfitLossCardState extends ConsumerState<ProfitLossCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final salaries = ref.watch(salaryRecordsProvider);
    if (expenses.isLoading || salaries.isLoading) {
      return const InsightCard(
        title: 'Profit & loss',
        subtitle: 'What is left after costs, month by month',
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final pnl = computePnl(
      months: widget.months,
      rollups: widget.insights.months,
      expenses: expenses.valueOrNull ?? const [],
      salaries: salaries.valueOrNull ?? const [],
    );
    final i = (_selected ?? pnl.length - 1).clamp(0, pnl.length - 1);
    final m = pnl[i];
    final total = pnl.fold<double>(0, (s, x) => s + x.profit);

    Widget line(String label, double v, {bool minus = true, bool strong = false, String? note, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: label),
                  if (note != null) TextSpan(text: '  $note', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ])),
              ),
              Text(
                '${minus && v > 0 ? '- ' : ''}${formatInr(v)}',
                style: TextStyle(
                  fontSize: strong ? 14 : 13,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                  color: color ?? AppTheme.slateDark,
                ),
              ),
            ],
          ),
        );

    return InsightCard(
      title: 'Profit & loss',
      subtitle: 'What is left after costs, month by month',
      headline: formatInr(total),
      headlineCaption: 'profit, ${widget.months.length} months',
      headlineColor: total < 0 ? AppTheme.accentRed : null,
      scopeNote: 'All branches',
      child: Column(
        children: [
          ColumnChart(
            labels: [for (final x in pnl) _monthLabel(x.month)],
            series: [ColumnSeries('Profit', kChartNavy, [for (final x in pnl) x.profit])],
            describe: (k) => '${pnl[k].profit < 0 ? 'Loss' : 'Profit'} ${formatInr(pnl[k].profit)} · margin ${_pct(pnl[k].marginPct)}',
            onSelect: (k) => setState(() => _selected = k),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.borderSubtle), borderRadius: BorderRadius.circular(12)),
            // merge, not replace: a bare DefaultTextStyle drops the app font.
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 13, color: AppTheme.slateMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_kMonths[m.month.month - 1]} ${m.month.year}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                  const SizedBox(height: 4),
                  line('Takings', m.revenue, minus: false, note: 'without GST'),
                  line('Product cost', m.productCost),
                  line('Expenses', m.expenses),
                  line('Staff pay', m.payroll, note: m.payrollEstimated ? 'estimate' : null),
                  const Divider(height: 14, color: AppTheme.borderSubtle),
                  line(
                    m.profit < 0 ? 'Loss' : 'Profit',
                    m.profit,
                    minus: false,
                    strong: true,
                    color: m.profit < 0 ? AppTheme.accentRed : AppTheme.slateDark,
                  ),
                  if (m.payrollEstimated)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Payroll not run for this month yet - staff pay is the commission earned so far.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Services vs products, plus discounts given away and GST collected.
class RevenueMixCard extends StatelessWidget {
  final RollupStats window;
  final String periodLabel;
  const RevenueMixCard({super.key, required this.window, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final services = window.serviceSales, products = window.productSales;
    final gross = services + products;
    final margin = products <= 0 ? 0.0 : (products - window.productCost) / products * 100;
    final discountShare = gross <= 0 ? 0.0 : window.discount / gross * 100;
    return InsightCard(
      title: 'Where the money comes from',
      subtitle: 'Services vs products, $periodLabel',
      scopeNote: 'All branches',
      child: Column(
        children: [
          if (gross <= 0)
            const InsightEmpty('Shows up once bills are raised with this version of the app, or after adding past months.')
          else
            DonutChart(
              slices: [
                DonutSlice('Services', services, kChartCategorical[0]),
                DonutSlice('Products', products, kChartCategorical[1]),
              ],
              centerValue: formatInrCompact(gross),
              centerCaption: 'before GST',
            ),
          const SizedBox(height: 16),
          InsightFigures([
            ('Discounts given', formatInr(window.discount), '${_pct(discountShare)} of sales'),
            ('GST collected', formatInr(window.tax), 'to pay the government'),
            ('Product margin', _pct(margin), products > 0 ? '${formatInr(products - window.productCost)} earned' : 'no product sales'),
          ]),
        ],
      ),
    );
  }
}

/// The last 30 days, one bar a day, split into services and products.
class DailyTakingsCard extends StatelessWidget {
  final InsightsData insights;
  const DailyTakingsCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = [for (var i = 29; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final services = <double>[], products = <double>[], unsplit = <double>[];
    var total = 0.0;
    for (final d in days) {
      final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final r = insights.days[key] ?? RollupStats.empty;
      total += r.sales;
      final split = r.serviceSales + r.productSales;
      if (split > 0) {
        // Scaled to the day's takings so the bar's height is what came in.
        services.add(r.sales * r.serviceSales / split);
        products.add(r.sales * r.productSales / split);
        unsplit.add(0);
      } else {
        services.add(0);
        products.add(0);
        unsplit.add(r.sales);
      }
    }
    final anyUnsplit = unsplit.any((v) => v > 0);
    return InsightCard(
      title: 'Last 30 days',
      subtitle: 'Takings each day',
      headline: formatInr(total),
      headlineCaption: '30-day total',
      scopeNote: 'All branches',
      child: total <= 0
          ? const InsightEmpty('No bills in the last 30 days.')
          : ColumnChart(
              labels: [for (final d in days) '${d.day} ${_kMonths[d.month - 1]}'],
              labelEvery: 7,
              height: 130,
              series: [
                ColumnSeries('Services', kChartCategorical[0], services),
                ColumnSeries('Products', kChartCategorical[1], products),
                if (anyUnsplit) ColumnSeries('Not split', kChartOther, unsplit),
              ],
            ),
    );
  }
}

/// Money owed, by how long it has been owed.
class DuesAgingCard extends StatelessWidget {
  final List<Bill> bills;
  final List<Customer> customers;
  const DuesAgingCard({super.key, required this.bills, required this.customers});

  @override
  Widget build(BuildContext context) {
    final a = computeDuesAging(bills, customers, DateTime.now());
    return InsightCard(
      title: 'Money owed',
      subtitle: 'Pay-later balances by how long they have been unpaid',
      headline: formatInr(a.total),
      headlineCaption: 'total due',
      headlineColor: a.total > 0 ? AppTheme.accentAmber : null,
      child: a.total <= 0
          ? const InsightEmpty('Nothing owed - every bill is paid.')
          : HBarList([
              HBarItem('Up to 7 days', a.days0to7, formatInr(a.days0to7), color: kChartNavySoft),
              HBarItem('8 - 30 days', a.days8to30, formatInr(a.days8to30), color: AppTheme.accentAmber),
              HBarItem('31 - 60 days', a.days31to60, formatInr(a.days31to60), color: AppTheme.accentRed),
              HBarItem('Over 60 days', a.over60, formatInr(a.over60), color: AppTheme.accentRed, caption: a.over60 > 0 ? 'Follow these up first' : null),
              if (a.undated > 0)
                HBarItem('Older bills', a.undated, formatInr(a.undated), color: kChartOther, caption: 'From bills before the ones loaded here'),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

class CategoryRevenueCard extends StatelessWidget {
  final RollupStats window;
  final List<ServiceCategory> categories;
  final String periodLabel;
  const CategoryRevenueCard({super.key, required this.window, required this.categories, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final names = {for (final c in categories) c.id: c.name};
    final byCat = window.group('byCategory');
    final slices = categoricalSlices(
      [for (final e in byCat.entries) (names[e.key] ?? 'Uncategorised', e.value)],
      format: formatInr,
    );
    final total = byCat.values.fold<double>(0, (s, v) => s + v);
    return InsightCard(
      title: 'Service takings by category',
      subtitle: 'Which kinds of work earn the most, $periodLabel',
      scopeNote: 'All branches',
      child: slices.isEmpty
          ? const InsightEmpty('Shows up once services are billed with this version of the app, or after adding past months.')
          : DonutChart(slices: slices, centerValue: formatInrCompact(total), centerCaption: 'services'),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------

class StaffProductivityCard extends StatelessWidget {
  final List<StaffMonth> staff;
  final RollupStats month;
  final String monthLabel;
  const StaffProductivityCard({super.key, required this.staff, required this.month, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final attach = month.billCount == 0 ? 0.0 : month.billsWithProduct / month.billCount * 100;
    final withSales = staff.where((s) => s.sales > 0 || s.daysPresent > 0).toList();
    return InsightCard(
      title: 'Team productivity',
      subtitle: 'Takings, hours on shift and punctuality, $monthLabel',
      headline: _pct(attach),
      headlineCaption: 'bills with a product',
      scopeNote: 'All branches',
      child: withSales.isEmpty
          ? const InsightEmpty('No staff takings or attendance for this month yet.')
          : HBarList([
              for (final s in withSales)
                HBarItem(
                  s.employee.name,
                  s.sales,
                  formatInr(s.sales),
                  caption: [
                    '${s.billsServed} bill${s.billsServed == 1 ? '' : 's'}',
                    if (s.billsServed > 0) 'avg ${formatInr(s.avgBill)}',
                    if (s.salesPerHour != null) '${formatInr(s.salesPerHour!)}/hr on shift',
                    '${s.daysPresent} day${s.daysPresent == 1 ? '' : 's'} in',
                    if (s.lateDays > 0) '${s.lateDays} late',
                  ].join(' · '),
                ),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Clients
// ---------------------------------------------------------------------------

class ClientMixCard extends StatelessWidget {
  final List<Customer> customers;
  final InsightsData insights;
  final List<DateTime> months;
  final String periodLabel;
  const ClientMixCard({super.key, required this.customers, required this.insights, required this.months, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final mix = computeClientMix(customers, months.first);
    final perMonth = [for (final m in months) insights.month(m).newClients.toDouble()];
    return InsightCard(
      title: 'New vs returning',
      subtitle: 'Clients who came in, $periodLabel',
      child: Column(
        children: [
          if (mix.total == 0)
            const InsightEmpty('No client visits in this period.')
          else
            DonutChart(
              slices: [
                DonutSlice('Returning', mix.returning.toDouble(), kChartCategorical[0], valueText: '${mix.returning}'),
                DonutSlice('New', mix.newClients.toDouble(), kChartCategorical[1], valueText: '${mix.newClients}'),
              ],
              centerValue: '${mix.total}',
              centerCaption: 'clients',
            ),
          if (perMonth.any((v) => v > 0)) ...[
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('First visits each month', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
            ),
            const SizedBox(height: 8),
            ColumnChart(
              labels: [for (final m in months) _monthLabel(m)],
              series: [ColumnSeries('New clients', kChartNavy, perMonth)],
              format: (v) => v.round().toString(),
              height: 110,
            ),
          ],
        ],
      ),
    );
  }
}

class ClientValueCard extends StatelessWidget {
  final List<Customer> customers;
  final ValueChanged<Customer>? onOpenClient;
  const ClientValueCard({super.key, required this.customers, this.onOpenClient});

  @override
  Widget build(BuildContext context) {
    final v = computeClientValue(customers);
    return InsightCard(
      title: 'Client value',
      subtitle: 'How often clients come back, all time',
      headline: formatInr(v.avgSpendPerVisit),
      headlineCaption: 'avg spend per visit',
      child: v.billedClients == 0
          ? const InsightEmpty('No billed clients yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DonutChart(
                  slices: [
                    DonutSlice('Once', v.oneVisit.toDouble(), kChartCategorical[0], valueText: '${v.oneVisit}'),
                    DonutSlice('2 - 4 visits', v.twoToFour.toDouble(), kChartCategorical[1], valueText: '${v.twoToFour}'),
                    DonutSlice('5 - 9 visits', v.fiveToNine.toDouble(), kChartCategorical[2], valueText: '${v.fiveToNine}'),
                    DonutSlice('10+ visits', v.tenPlus.toDouble(), kChartCategorical[3], valueText: '${v.tenPlus}'),
                  ],
                  centerValue: '${v.billedClients}',
                  centerCaption: 'billed clients',
                ),
                const SizedBox(height: 16),
                InsightFigures([
                  ('Avg per client', formatInr(v.avgLifetimeSpend), 'all visits together'),
                  ('Came once only', _pct(v.oneVisit / v.billedClients * 100), 'worth a follow-up'),
                ]),
                const SizedBox(height: 16),
                const Text('Top clients', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                const SizedBox(height: 4),
                for (final c in v.topClients)
                  DsListRow(
                    leading: DsAvatar(c.name, size: 32),
                    title: c.name,
                    subtitle: '${c.visitCount} visit${c.visitCount == 1 ? '' : 's'}',
                    trailing: Text(formatInr(c.totalSpent), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
                    onTap: onOpenClient == null ? null : () => onOpenClient!(c),
                  ),
              ],
            ),
    );
  }
}

class ClientDetailsCard extends StatelessWidget {
  final List<Customer> customers;
  const ClientDetailsCard({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    final d = computeClientDetails(customers);
    return InsightCard(
      title: 'Client details on file',
      subtitle: 'Who WhatsApp messages and birthday wishes can reach',
      child: d.total == 0
          ? const InsightEmpty('No clients yet.')
          : Column(
              children: [
                ShareBar(label: 'OK to WhatsApp', part: d.whatsappOptIn, whole: d.total, hint: 'Only these clients get bills, birthday wishes and reminders'),
                const SizedBox(height: 14),
                ShareBar(label: 'Birthday saved', part: d.withBirthday, whole: d.total),
                const SizedBox(height: 14),
                ShareBar(label: 'Email saved', part: d.withEmail, whole: d.total),
                const SizedBox(height: 18),
                DonutChart(
                  size: 112,
                  slices: [
                    DonutSlice('Women', d.female.toDouble(), kChartCategorical[0], valueText: '${d.female}'),
                    DonutSlice('Men', d.male.toDouble(), kChartCategorical[1], valueText: '${d.male}'),
                    if (d.otherGender > 0) DonutSlice('Other', d.otherGender.toDouble(), kChartCategorical[2], valueText: '${d.otherGender}'),
                    if (d.unknownGender > 0) DonutSlice('Not recorded', d.unknownGender.toDouble(), kChartOther, valueText: '${d.unknownGender}'),
                  ],
                  centerValue: '${d.total}',
                  centerCaption: 'clients',
                ),
              ],
            ),
    );
  }
}

/// What the automatic WhatsApp messages did: how many went out, and how many
/// reminded clients came back within 30 days (and what they spent).
class WhatsAppResultsCard extends StatelessWidget {
  final RollupStats window;
  final String periodLabel;
  const WhatsAppResultsCard({super.key, required this.window, required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    final reminders = window['wa.reminders'].round();
    final back = window.reminderReturns;
    return InsightCard(
      title: 'WhatsApp results',
      subtitle: 'Automatic messages and what they brought in, $periodLabel',
      headline: formatInr(window.reminderReturnSales),
      headlineCaption: 'from reminded clients',
      child: Column(
        children: [
          InsightFigures([
            ('Bill receipts', '${window['wa.receipts'].round()}', 'sent'),
            ('Birthday wishes', '${window['wa.birthdays'].round()}', 'sent'),
            ('Reminders', '$reminders', 'sent'),
          ]),
          const SizedBox(height: 16),
          ShareBar(
            label: 'Came back after a reminder',
            part: back,
            whole: reminders < back ? back : reminders,
            hint: 'Billed within 30 days of getting the reminder',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock
// ---------------------------------------------------------------------------

class StockValueCard extends StatelessWidget {
  final StockInsights stock;
  const StockValueCard({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};
    for (final p in stock.products) {
      final cat = p.item.category.trim().isEmpty ? 'Other' : p.item.category.trim();
      byCategory[cat] = (byCategory[cat] ?? 0) + p.valueAtCost;
    }
    final slices = categoricalSlices([for (final e in byCategory.entries) (e.key, e.value)], format: formatInr);
    return InsightCard(
      title: 'Stock on the shelf',
      subtitle: 'Money tied up in products right now',
      headline: formatInr(stock.valueAtCost),
      headlineCaption: 'at cost price',
      child: stock.products.isEmpty
          ? const InsightEmpty('No products in stock.')
          : Column(
              children: [
                if (slices.isNotEmpty)
                  DonutChart(slices: slices, centerValue: formatInrCompact(stock.valueAtCost), centerCaption: 'at cost'),
                const SizedBox(height: 16),
                InsightFigures([
                  ('If all sold', formatInr(stock.valueAtPrice), 'at selling price'),
                  ('Profit in stock', formatInr(stock.potentialProfit), stock.valueAtPrice > 0 ? '${_pct(stock.potentialProfit / stock.valueAtPrice * 100)} margin' : null),
                ]),
              ],
            ),
    );
  }
}

class StockHealthCard extends StatelessWidget {
  final StockInsights stock;
  const StockHealthCard({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final running = stock.runningOut.take(6).toList();
    final idle = ([...stock.notSelling]..sort((a, b) => b.valueAtCost.compareTo(a.valueAtCost))).take(6).toList();
    final byMargin = [...stock.products.where((p) => p.item.price > 0)]..sort((a, b) => a.marginPct.compareTo(b.marginPct));
    final lowMargin = byMargin.where((p) => p.marginPct < 25).take(5).toList();

    Widget section(String title, String hint, List<Widget> rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
            Text(hint, style: const TextStyle(fontSize: 11, color: AppTheme.slateLight)),
            const SizedBox(height: 10),
            ...rows,
          ],
        );

    return InsightCard(
      title: 'Stock health',
      subtitle: 'Based on sales in the last ${stock.daysCovered} day${stock.daysCovered == 1 ? '' : 's'}',
      child: stock.products.isEmpty
          ? const InsightEmpty('No products yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section(
                  'Running out soon',
                  'Will last two weeks or less at the current rate',
                  running.isEmpty
                      ? [const InsightEmpty('Nothing is about to run out.')]
                      : [
                          HBarList([
                            for (final p in running)
                              HBarItem(
                                p.item.name,
                                // Fewer days left = longer, more urgent bar.
                                14 - p.daysLeft!.clamp(0, 14),
                                '${p.daysLeft!.floor()} day${p.daysLeft!.floor() == 1 ? '' : 's'} left',
                                caption: '${p.item.stockCount} in stock · ${p.unitsSold} sold',
                                color: p.daysLeft! <= 5 ? AppTheme.accentRed : AppTheme.accentAmber,
                              ),
                          ]),
                        ],
                ),
                const SizedBox(height: 18),
                section(
                  'Not selling',
                  stock.daysCovered < 14 ? 'Needs two weeks of bills to judge' : 'In stock, no sale in the last ${stock.daysCovered} days',
                  idle.isEmpty
                      ? [InsightEmpty(stock.daysCovered < 14 ? 'Not enough history yet.' : 'Every product in stock has sold.')]
                      : [
                          for (final p in idle)
                            DsValueRow(label: '${p.item.name}  ·  ${p.item.stockCount} in stock', value: formatInr(p.valueAtCost)),
                        ],
                ),
                if (lowMargin.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  section(
                    'Low margin',
                    'Selling price less than 25% above cost',
                    [
                      for (final p in lowMargin)
                        DsValueRow(
                          label: '${p.item.name}  ·  ${formatInr(p.item.costPrice)} -> ${formatInr(p.item.price)}',
                          value: _pct(p.marginPct),
                          valueColor: p.marginPct < 0 ? AppTheme.accentRed : AppTheme.accentAmber,
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Convenience for Reports: rollups for a window, plus the oldest bill the
/// app knows about (to decide whether the backfill banner is worth showing).
DateTime? oldestLoadedBill(AppData state) {
  DateTime? oldest;
  for (final b in state.bills) {
    final t = b.createdAt;
    if (t != null && (oldest == null || t.isBefore(oldest))) oldest = t;
  }
  return oldest;
}
