// Every Reports insight card has to lay out cleanly at phone width and on a
// wide screen, with data and without it - a RenderFlex overflow fails the
// test, the way it would show as a yellow-black stripe in the app.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/expenses_provider.dart';
import 'package:mobile/data/insights.dart';
import 'package:mobile/data/insights_provider.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/data/salary_provider.dart';
import 'package:mobile/features/owner/widgets/owner_insights.dart';

class FixedExpenses extends ExpensesNotifier {
  @override
  Future<List<Expense>> build() async => [
        Expense(id: 'e', title: 'Rent', amount: 15000, category: 'RENT', date: DateTime(2026, 10, 3)),
      ];
}

class FixedSalaries extends SalaryRecordsNotifier {
  @override
  Future<List<SalaryRecord>> build() async => [
        SalaryRecord(id: 's', employeeId: 'e1', month: 9, year: 2026, baseSalary: 12000, commissionEarned: 3000, deductions: 0, totalPaid: 15000, status: 'PAID'),
      ];
}

Customer _c(String id, int visits, double spent, {String? gender, bool wa = false}) => Customer(
      id: id,
      name: 'Client with a fairly long name $id',
      phone: '9$id',
      isVip: false,
      branchId: 'br1',
      createdAt: DateTime(2026, 1, 1),
      visitCount: visits,
      totalSpent: spent,
      outstandingBalance: visits.isEven ? 250 : 0,
      lastVisitAt: DateTime(2026, 10, 20),
      gender: gender,
      whatsappOptIn: wa,
      birthday: wa ? '03-14' : null,
    );

InventoryItem _p(String id, {int stock = 8, double cost = 300, double price = 350}) => InventoryItem(
      id: id,
      sku: id,
      name: 'Keratin shampoo 500 ml $id',
      category: id.startsWith('h') ? 'Hair care' : 'Skin',
      price: price,
      costPrice: cost,
      stockCount: stock,
      minAlertThreshold: 2,
    );

Bill _b(String id, DateTime at, {String product = 'h1', double paid = 1000}) => Bill(
      id: id,
      invoiceNumber: id,
      customerId: 'c$id',
      branchId: 'br1',
      subTotal: 1000,
      discountAmount: 0,
      taxAmount: 0,
      finalAmount: 1000,
      paymentMethod: 'CASH',
      amountPaid: paid,
      status: 'COMPLETED',
      createdAt: at,
      items: [
        BillItem(id: '$id-1', type: 'PRODUCT', inventoryItemId: product, quantity: 3, unitPrice: 350, discountAmount: 0, employeeId: 'e1', calculatedCommission: 0),
      ],
    );

final _now = DateTime.now();
final _months = lastMonths(_now, 6);

InsightsData _insights() {
  final months = <String, RollupStats>{};
  for (var i = 0; i < _months.length; i++) {
    final slots = <String, dynamic>{};
    for (var d = 1; d <= 7; d++) {
      for (var h = 10; h <= 20; h++) {
        slots['${d}_${h.toString().padLeft(2, '0')}'] = (d * h + i) % 9;
      }
    }
    months[monthKey(_months[i])] = RollupStats.fromDoc({
      'sales': 80000.0 + i * 9000,
      'billCount': 90 + i * 5,
      'tax': 4000,
      'discount': 2500,
      'serviceSales': 70000,
      'productSales': 12000,
      'productCost': 7000,
      'commission': 6000,
      'newClients': 8 + i,
      'billsWithProduct': 30,
      'reminderReturns': 4,
      'reminderReturnSales': 5200,
      'byStaff': {'e1': 40000, 'e2': 30000},
      'staffBills': {'e1': 50, 'e2': 40},
      'byCategory': {'cat1': 30000, 'cat2': 20000, 'cat3': 9000, 'cat4': 6000, 'cat5': 3000, 'none': 2000},
      'slots': slots,
      'wa': {'receipts': 80, 'birthdays': 6, 'reminders': 20},
    });
  }
  final days = <String, RollupStats>{};
  for (var i = 0; i < 30; i++) {
    final d = DateTime(_now.year, _now.month, _now.day - i);
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    days[key] = RollupStats.fromDoc(i > 20
        ? {'sales': 2500.0}
        : {'sales': 3000.0 + i * 80, 'serviceSales': 2500, 'productSales': 400});
  }
  return InsightsData(months: months, days: days, liveSince: _now, backfillDone: true);
}

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
      branchId: 'br1',
    );

List<Widget> _cards({required bool empty}) {
  final insights = empty ? const InsightsData(months: {}, days: {}, liveSince: null, backfillDone: true) : _insights();
  final customers = empty ? <Customer>[] : [for (var i = 0; i < 40; i++) _c('$i', i % 12, 900.0 * (i % 12), gender: ['FEMALE', 'MALE', null][i % 3], wa: i.isEven)];
  final inventory = empty ? <InventoryItem>[] : [_p('h1', stock: 4), _p('h2', stock: 20, cost: 340), _p('s1', stock: 6), _p('s2', stock: 0)];
  final bills = empty
      ? <Bill>[]
      : [
          _b('a', _now.subtract(const Duration(days: 40))),
          _b('b', _now.subtract(const Duration(days: 3)), paid: 0),
          _b('c', _now.subtract(const Duration(days: 20)), paid: 400),
        ];
  final window = insights.window(_months);
  final month = insights.month(_months.last);
  return [
    const InsightsBackfillBanner(),
    BusyHoursCard(window: window, periodLabel: 'last 6 months', scopeNote: 'All branches'),
    ProfitLossCard(months: _months, insights: insights),
    RevenueMixCard(window: window, periodLabel: 'last 6 months'),
    DailyTakingsCard(insights: insights),
    DuesAgingCard(bills: bills, customers: customers),
    CategoryRevenueCard(
      window: window,
      categories: [for (var i = 1; i <= 5; i++) ServiceCategory(id: 'cat$i', name: 'Category number $i')],
      periodLabel: 'last 6 months',
    ),
    StaffProductivityCard(
      staff: computeStaffMonth(
        employees: [_e('e1', 'Priya Sharma'), _e('e2', 'Rahul')],
        attendance: [
          AttendanceRecord(id: 'a', employeeId: 'e1', date: monthStart(_now), clockIn: monthStart(_now).add(const Duration(hours: 10)), clockOut: monthStart(_now).add(const Duration(hours: 19)), status: 'LATE'),
        ],
        month: month,
        monthStartDate: monthStart(_now),
      ),
      month: month,
      monthLabel: 'Oct 2026',
    ),
    ClientMixCard(customers: customers, insights: insights, months: _months, periodLabel: 'last 6 months'),
    ClientValueCard(customers: customers),
    ClientDetailsCard(customers: customers),
    WhatsAppResultsCard(window: window, periodLabel: 'last 6 months'),
    StockValueCard(stock: computeStockInsights(inventory, bills, _now)),
    StockHealthCard(stock: computeStockInsights(inventory, bills, _now)),
  ];
}

Future<void> _pumpAt(WidgetTester tester, double width, {required bool empty}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      expensesProvider.overrideWith(FixedExpenses.new),
      salaryRecordsProvider.overrideWith(FixedSalaries.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final c in _cards(empty: empty)) ...[c, const SizedBox(height: 14)],
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 1024.0]) {
    testWidgets('insight cards lay out at ${width.round()}px with data', (tester) async {
      await _pumpAt(tester, width, empty: false);
      expect(tester.takeException(), isNull);
      // Scroll through so every card is built and laid out.
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 30; i++) {
        await tester.drag(list, const Offset(0, -700));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('insight cards lay out at ${width.round()}px with no data', (tester) async {
      await _pumpAt(tester, width, empty: true);
      expect(tester.takeException(), isNull);
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 20; i++) {
        await tester.drag(list, const Offset(0, -700));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('profit and loss shows the selected month breakdown', (tester) async {
    await _pumpAt(tester, 400, empty: false);
    expect(find.text('Profit & loss'), findsOneWidget);
    expect(find.textContaining('Payroll not run'), findsOneWidget);
    expect(find.text('Busy hours'), findsOneWidget);
  });
}

