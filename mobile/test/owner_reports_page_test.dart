// Reports (owner_reports_page.dart): every section lays out at phone and
// laptop width, opens with its answer, and steps through months - with data
// and on an empty salon. A RenderFlex overflow fails the test, the way it
// would show as a striped bar in the app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
import 'package:mobile/data/expenses_provider.dart';
import 'package:mobile/data/insights.dart';
import 'package:mobile/data/insights_provider.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/data/report_summary.dart';
import 'package:mobile/data/salary_provider.dart';
import 'package:mobile/features/owner/widgets/owner_reports_page.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month, 1);
final _lastMonth = DateTime(_now.year, _now.month - 1, 1);

EmployeeProfile _e(String id, String name) => EmployeeProfile(
      id: id,
      userId: id,
      email: '$id@x.test',
      name: name,
      phone: '1',
      roleTitle: 'Stylist',
      active: true,
      baseSalary: 0,
      serviceCommissionPct: 0,
      productCommissionPct: 0,
      branchId: 'b1',
    );

Customer _c(String id, {int daysAgo = 40, double owed = 0}) => Customer(
      id: id,
      name: 'Client with a fairly long name $id',
      phone: '98765$id',
      isVip: false,
      branchId: 'b1',
      visitCount: 3,
      totalSpent: 2400,
      outstandingBalance: owed,
      lastVisitAt: _now.subtract(Duration(days: daysAgo)),
    );

AppData _data({required bool empty}) => AppData(
      branches: [
        Branch(id: 'b1', name: 'Main', active: true, employeeCount: 2, customerCount: 3, monthlyRevenue: 0),
        Branch(id: 'b2', name: 'Vijay Nagar', active: true, employeeCount: 1, customerCount: 1, monthlyRevenue: 0),
      ],
      employees: empty ? const [] : [_e('e1', 'Priya Sharma'), _e('e2', 'Rahul')],
      customers: empty ? const [] : [_c('1', owed: 1200), _c('2', daysAgo: 50), _c('3', daysAgo: 5)],
      categories: [ServiceCategory(id: 'cat1', name: 'Hair')],
      services: [SalonService(id: 's1', name: 'Haircut', price: 300, categoryId: 'cat1')],
      inventory: empty
          ? const []
          : [InventoryItem(id: 'p1', sku: 'p1', name: 'Shampoo', category: 'Hair', price: 350, costPrice: 200, stockCount: 3, minAlertThreshold: 2)],
      bills: const [],
      salesTargets: const [],
      commissions: const [],
      attendance: const [],
      dashboard: null,
      settings: SalonSettings(salonName: 'Cuts', gstRate: 0, lateAttendancePenalty: 0, whatsappReady: true),
    );

class _StubApp extends AppDataNotifier {
  _StubApp(this.d);
  final AppData d;
  @override
  Future<AppData> build() async => d;
}

class _StubInsights extends InsightsNotifier {
  _StubInsights(this.empty);
  final bool empty;
  @override
  Future<InsightsData> build() async {
    if (empty) return const InsightsData(months: {}, days: {}, liveSince: null, backfillDone: true);
    final months = <String, RollupStats>{};
    for (var i = 0; i < 13; i++) {
      final m = DateTime(_now.year, _now.month - i, 1);
      months[monthKey(m)] = RollupStats.fromDoc({
        'sales': 58000.0 - i * 2000,
        'billCount': 120 - i,
        'tax': 3000,
        'discount': 1200,
        'serviceSales': 48000,
        'productSales': 9000,
        'productCost': 5000,
        'commission': 6000,
        'serviceCount': 140,
        'productUnits': 30,
        'newClients': 12,
        'reminderReturns': 4,
        'reminderReturnSales': 5200,
        'byStaff': {'e1': 30000, 'e2': 20000},
        'staffBills': {'e1': 60, 'e2': 50},
        'byCategory': {'cat1': 48000},
        'byBranch': {'b1': 40000, 'b2': 18000},
        'byService': {'s1': 30000, 'gone': 18000},
        'serviceQty': {'s1': 100, 'gone': 40},
        'slots': {'6_11': 9, '6_17': 4, '2_10': 1},
        'wa': {'reminders': 20},
      });
    }
    return InsightsData(months: months, days: const {}, liveSince: _now, backfillDone: true);
  }
}

class _NoExpenses extends ExpensesNotifier {
  @override
  Future<List<Expense>> build() async => [
        Expense(id: 'x', title: 'Rent', amount: 15000, category: 'RENT', date: _thisMonth.add(const Duration(days: 1))),
      ];
}

class _NoSalaries extends SalaryRecordsNotifier {
  @override
  Future<List<SalaryRecord>> build() async => const [];
}

Future<void> _pump(WidgetTester tester, double width, {bool empty = false}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDataProvider.overrideWith(() => _StubApp(_data(empty: empty))),
      insightsProvider.overrideWith(() => _StubInsights(empty)),
      expensesProvider.overrideWith(_NoExpenses.new),
      salaryRecordsProvider.overrideWith(_NoSalaries.new),
    ],
    child: const MaterialApp(home: Scaffold(body: OwnerReportsTab())),
  ));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, ReportSection s, {required bool wide}) async {
  await tester.tap(find.byKey(Key(wide ? 'reportsIndex_${s.name}' : 'reportsChip_${s.name}')));
  await tester.pumpAndSettle();
}

Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).last;
  for (var i = 0; i < 8; i++) {
    await tester.drag(list, const Offset(0, -600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
  await tester.drag(list, const Offset(0, 6000));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1180.0]) {
    final wide = width >= 900;
    for (final empty in [false, true]) {
      testWidgets('every section lays out at ${width.round()}px${empty ? ', empty salon' : ''}', (tester) async {
        await _pump(tester, width, empty: empty);
        for (final s in ReportSection.values) {
          await _open(tester, s, wide: wide);
          expect(tester.takeException(), isNull, reason: s.title);
          expect(find.byKey(const Key('reportsAnswer')), findsOneWidget, reason: s.title);
          await _scrollThrough(tester);
        }
      });
    }
  }

  testWidgets('takings answer compares with last month', (tester) async {
    await _pump(tester, 1180);
    expect(find.text('₹58,000'), findsWidgets);
    expect(find.textContaining('more than ${reportMonthName(_lastMonth)}'), findsOneWidget);
  });

  testWidgets('profit is takings without GST minus costs', (tester) async {
    await _pump(tester, 1180);
    await _open(tester, ReportSection.profit, wide: true);
    // 58,000 - 3,000 GST - 5,000 products - 15,000 rent - 6,000 commission.
    expect(find.text('₹29,000'), findsWidgets);
    expect(find.textContaining("Payroll hasn't been run"), findsOneWidget);
  });

  testWidgets('team names the top earner and lists services by name', (tester) async {
    await _pump(tester, 1180);
    await _open(tester, ReportSection.team, wide: true);
    expect(find.text('Priya Sharma'), findsWidgets);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Removed service'), findsOneWidget);
  });

  testWidgets('the month steps back and forward, not past this month', (tester) async {
    await _pump(tester, 360);
    expect(find.text('${reportMonthName(_thisMonth)} ${_thisMonth.year}'), findsOneWidget);
    final next = tester.widget<IconButton>(find.byKey(const Key('reportsNextMonth')));
    expect(next.onPressed, isNull);
    await tester.tap(find.byKey(const Key('reportsPrevMonth')));
    await tester.pumpAndSettle();
    expect(find.text('${reportMonthName(_lastMonth)} ${_lastMonth.year}'), findsOneWidget);
    expect(find.text('₹56,000'), findsWidgets);
  });
}
