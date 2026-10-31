// Reports' analytics: the rollup a bill writes has to add up to the same
// figures the backfill derives from the bills, and the read side has to add
// live and backfilled parts without counting anything twice.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/insights.dart';
import 'package:mobile/data/models.dart';

BillItem _item(String type, {double price = 100, int qty = 1, double discount = 0, String emp = 'e1', String? serviceId, String? productId}) =>
    BillItem(
      id: 'i$type$emp$price',
      type: type,
      serviceId: serviceId,
      inventoryItemId: productId,
      quantity: qty,
      unitPrice: price,
      discountAmount: discount,
      employeeId: emp,
      calculatedCommission: price * qty * 0.1,
    );

Bill _bill(String id, DateTime at, List<BillItem> items, {double? total, double paid = -1, String customer = 'c1'}) {
  final sum = items.fold<double>(0, (s, i) => s + i.unitPrice * i.quantity - i.discountAmount);
  final finalAmount = total ?? sum;
  return Bill(
    id: id,
    invoiceNumber: 'INV-$id',
    customerId: customer,
    branchId: 'br1',
    subTotal: sum,
    discountAmount: 0,
    taxAmount: 0,
    finalAmount: finalAmount,
    paymentMethod: 'CASH',
    amountPaid: paid < 0 ? finalAmount : paid,
    status: 'COMPLETED',
    createdAt: at,
    items: items,
  );
}

Customer _customer(String id, {int visits = 1, double spent = 0, DateTime? created, DateTime? last, double owed = 0, bool wa = false, String? birthday, String? gender}) =>
    Customer(
      id: id,
      name: 'Client $id',
      phone: '9$id',
      isVip: false,
      branchId: 'br1',
      createdAt: created,
      visitCount: visits,
      totalSpent: spent,
      outstandingBalance: owed,
      lastVisitAt: last,
      whatsappOptIn: wa,
      birthday: birthday,
      gender: gender,
    );

InventoryItem _product(String id, {double price = 200, double cost = 120, int stock = 10}) => InventoryItem(
      id: id,
      sku: id,
      name: 'Product $id',
      category: 'Hair',
      price: price,
      costPrice: cost,
      stockCount: stock,
      minAlertThreshold: 2,
    );

void main() {
  group('billRollupFields', () {
    final at = DateTime(2026, 10, 24, 18, 30); // a Saturday
    final fields = billRollupFields(
      at: at,
      finalAmount: 590,
      discount: 10,
      tax: 90,
      branchId: 'br1',
      firstVisit: true,
      reminderReturn: true,
      monthly: true,
      lines: const [
        RollupLine(type: 'SERVICE', employeeId: 'e1', net: 300, categoryId: 'cat1', serviceId: 's1', commission: 30),
        RollupLine(type: 'SERVICE', employeeId: 'e2', net: 100, serviceId: 's1', commission: 10),
        RollupLine(type: 'PRODUCT', employeeId: 'e1', net: 110, quantity: 2, unitCost: 40, commission: 5),
      ],
    );

    test('totals, split and per-person figures', () {
      expect(fields['sales'], 590);
      expect(fields['billCount'], 1);
      expect(fields['serviceSales'], 400);
      expect(fields['productSales'], 110);
      expect(fields['productCost'], 80);
      expect(fields['commission'], 45);
      expect(fields['byStaff.e1'], 410);
      expect(fields['byStaff.e2'], 100);
      // One bill served, however many lines that person did on it.
      expect(fields['staffBills.e1'], 1);
      expect(fields['byCategory.cat1'], 300);
      expect(fields['byCategory.none'], 100);
      expect(fields['billsWithProduct'], 1);
      expect(fields['newClients'], 1);
      expect(fields['reminderReturns'], 1);
      expect(fields['reminderReturnSales'], 590);
      expect(fields['byBranch.br1'], 590);
      // Per service, month docs only (Reports' top services).
      expect(fields['byService.s1'], 400);
      expect(fields['serviceQty.s1'], 2);
    });

    test('monthly docs get the weekday x hour grid, daily docs the hour', () {
      expect(fields['slots.6_18'], 1);
      final daily = billRollupFields(
        at: at,
        finalAmount: 1,
        discount: 0,
        tax: 0,
        branchId: '',
        lines: const [],
        firstVisit: false,
        reminderReturn: false,
        monthly: false,
      );
      expect(daily['byHour.18'], 1);
      expect(daily.keys.where((k) => k.startsWith('slots.')), isEmpty);
      expect(daily.containsKey('newClients'), isFalse);
    });

    test('nest turns dotted keys into maps', () {
      final nested = nestRollupFields({'sales': 5, 'byStaff.e1': 3, 'byStaff.e2': 2}, (v) => v * 10);
      expect(nested, {
        'sales': 50,
        'byStaff': {'e1': 30, 'e2': 20},
      });
    });
  });

  group('RollupStats', () {
    test('adds the live counters and the backfilled pre part', () {
      final r = RollupStats.fromDoc({
        'sales': 1000,
        'billCount': 2,
        'byStaff': {'e1': 600},
        'liveSince': 'not a number',
        'pre': {
          'sales': 500,
          'billCount': 1,
          'byStaff': {'e1': 100, 'e2': 400},
        },
      });
      expect(r.sales, 1500);
      expect(r.billCount, 3);
      expect(r.group('byStaff'), {'e1': 700, 'e2': 400});
    });

    test('sum over months', () {
      final a = RollupStats.fromDoc({'sales': 100, 'tax': 18});
      final b = RollupStats.fromDoc({'sales': 50});
      final s = RollupStats.sum([a, b, RollupStats.empty]);
      expect(s.sales, 150);
      expect(s.tax, 18);
      expect(RollupStats.empty.hasData, isFalse);
    });
  });

  group('backfillMonthlyRollups', () {
    test('counts only bills before the cutoff, by month, first visit once', () {
      final services = [SalonService(id: 's1', name: 'Cut', price: 100, categoryId: 'cat1')];
      final inventory = [_product('p1', cost: 30)];
      final customers = [_customer('c1', created: DateTime(2026, 8, 20))];
      final bills = [
        _bill('a', DateTime(2026, 9, 1, 11), [_item('SERVICE', serviceId: 's1')]),
        _bill('b', DateTime(2026, 9, 15, 12), [_item('PRODUCT', price: 50, qty: 2, productId: 'p1')]),
        _bill('c', DateTime(2026, 10, 2, 12), [_item('SERVICE', serviceId: 's1')]),
        // At/after the cutoff: the live rollups already have it.
        _bill('d', DateTime(2026, 10, 20, 12), [_item('SERVICE', serviceId: 's1')]),
      ];
      final out = backfillMonthlyRollups(
        bills: bills,
        customers: customers,
        services: services,
        inventory: inventory,
        cutoff: DateTime(2026, 10, 20),
        windowStart: DateTime(2026, 1, 1),
      );
      expect(out.keys, unorderedEquals(['2026-09', '2026-10']));
      expect(out['2026-09']!['sales'], 200);
      expect(out['2026-09']!['billCount'], 2);
      expect(out['2026-09']!['newClients'], 1);
      expect(out['2026-09']!['productCost'], 60);
      expect(out['2026-09']!['byCategory.cat1'], 100);
      expect(out['2026-10']!['sales'], 100);
      expect(out['2026-10']!.containsKey('newClients'), isFalse);
    });
  });

  group('snapshot figures', () {
    test('client value bands and averages', () {
      final v = computeClientValue([
        _customer('a', visits: 1, spent: 500),
        _customer('b', visits: 3, spent: 1500),
        _customer('c', visits: 12, spent: 12000),
        _customer('d', visits: 0),
      ]);
      expect([v.oneVisit, v.twoToFour, v.fiveToNine, v.tenPlus, v.neverBilled], [1, 1, 0, 1, 1]);
      expect(v.avgSpendPerVisit, 875); // 14000 / 16 visits
      expect(v.topClients.first.id, 'c');
    });

    test('new vs returning in a window', () {
      final from = DateTime(2026, 10, 1);
      final mix = computeClientMix([
        _customer('a', visits: 1, last: DateTime(2026, 10, 5)),
        _customer('b', visits: 4, created: DateTime(2026, 1, 1), last: DateTime(2026, 10, 6)),
        _customer('c', visits: 3, created: DateTime(2026, 10, 2), last: DateTime(2026, 10, 9)),
        _customer('d', visits: 5, last: DateTime(2026, 9, 1)),
      ], from);
      expect(mix.newClients, 2);
      expect(mix.returning, 1);
    });

    test('dues by age, plus balances older than the loaded bills', () {
      final now = DateTime(2026, 10, 27);
      final a = computeDuesAging([
        _bill('a', DateTime(2026, 10, 25), [_item('SERVICE')], paid: 0),
        _bill('b', DateTime(2026, 10, 10), [_item('SERVICE')], paid: 40),
        _bill('c', DateTime(2026, 7, 1), [_item('SERVICE')], paid: 0),
        _bill('d', DateTime(2026, 10, 20), [_item('SERVICE')]),
      ], [
        _customer('c1', owed: 400),
      ], now);
      expect(a.days0to7, 100);
      expect(a.days8to30, 60);
      expect(a.over60, 100);
      expect(a.undated, 140);
      expect(a.billsOwing, 3);
      expect(a.total, 400);
    });

    test('stock value, days left and products not selling', () {
      final now = DateTime(2026, 10, 27);
      final s = computeStockInsights(
        [_product('fast', stock: 6), _product('idle', stock: 4)],
        [
          _bill('old', DateTime(2026, 9, 1), [_item('SERVICE')]),
          _bill('x', DateTime(2026, 10, 20), [_item('PRODUCT', qty: 15, productId: 'fast')]),
        ],
        now,
      );
      expect(s.valueAtCost, 1200);
      expect(s.valueAtPrice, 2000);
      expect(s.daysCovered, 30);
      expect(s.runningOut.single.item.id, 'fast');
      expect(s.runningOut.single.daysLeft, closeTo(12, 0.01)); // 6 left at 0.5/day
      expect(s.notSelling.single.item.id, 'idle');
    });

    test('profit and loss uses payroll slips, else commission so far', () {
      final pnl = computePnl(
        months: [DateTime(2026, 9, 1), DateTime(2026, 10, 1)],
        rollups: {
          '2026-09': RollupStats.fromDoc({'sales': 11800, 'tax': 1800, 'productCost': 500, 'commission': 900}),
          '2026-10': RollupStats.fromDoc({'sales': 5000, 'commission': 400}),
        },
        expenses: [
          Expense(id: 'e', title: 'Rent', amount: 3000, category: 'RENT', date: DateTime(2026, 9, 5)),
        ],
        salaries: [
          SalaryRecord(id: 's', employeeId: 'e1', month: 9, year: 2026, baseSalary: 4000, commissionEarned: 900, deductions: 0, totalPaid: 4900, status: 'PAID'),
        ],
      );
      expect(pnl[0].revenue, 10000);
      expect(pnl[0].profit, 10000 - 500 - 3000 - 4900);
      expect(pnl[0].payrollEstimated, isFalse);
      expect(pnl[1].payroll, 400);
      expect(pnl[1].payrollEstimated, isTrue);
    });
  });
}
