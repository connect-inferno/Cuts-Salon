// The bill history's search box and filter chips sit in a pinned
// SliverPersistentHeader, and a pinned header has to declare its extent
// before it lays anything out - so _HistoryHeaderDelegate's heights are
// hard-coded constants rather than measured. That is only safe while the
// controls inside actually fit. Above it, the Today's Collections table
// scrolls away with the list.
//
// These tests pump the real view at narrow, phone and tablet widths, at rest
// and scrolled, and fail on any render overflow. If someone adds a line to
// the header or bumps a font size, this is what catches it instead of an
// overflow stripe appearing on a salon's till.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/widgets/bill_history_view.dart';

Bill _bill(int i, {double paid = 500}) => Bill(
      id: 'b$i',
      invoiceNumber: 'INV-${i.toString().padLeft(4, '0')}',
      customerId: 'c1',
      customerName: 'Priya Ramakrishnan',
      branchId: 'br1',
      subTotal: 500,
      discountAmount: 0,
      taxAmount: 0,
      finalAmount: 500,
      paymentMethod: 'UPI',
      amountPaid: paid,
      status: 'COMPLETED',
      createdAt: DateTime.now().subtract(Duration(minutes: i)),
      items: const [],
    );

AppData _appData({int billCount = 30}) => AppData(
      branches: const [],
      employees: const [],
      customers: const [],
      categories: const [],
      services: const [],
      inventory: const [],
      // One part-paid bill so the Outstanding tile shows a real figure and
      // its "Awaiting collection" line, which is the taller of the two states.
      bills: [
        if (billCount > 0) _bill(0, paid: 300),
        for (var i = 1; i < billCount; i++) _bill(i),
      ],
      discountRequests: const [],
      salesTargets: const [],
      commissions: const [],
      attendance: const [],
      dashboard: null,
      settings: null,
    );

Future<void> _pumpAt(WidgetTester tester, Size size, {AppData? data}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BillHistoryView(state: data ?? _appData())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(375, 812);
  const narrow = Size(320, 640); // smallest phone worth supporting
  const tablet = Size(1024, 768);

  for (final entry in const {'narrow': narrow, 'phone': phone, 'tablet': tablet}.entries) {
    testWidgets('history renders without overflow at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value);

      expect(find.text("Today's Collections"), findsOneWidget);
      expect(find.text('Total Collected'), findsOneWidget);

      // The controls must fit inside the header's fixed extent - the header
      // clips rather than throws, so too small a height crops them silently.
      // The sliver itself has no box to measure; its top-level Container does.
      final header = tester.getRect(
        find.descendant(of: find.byType(SliverPersistentHeader), matching: find.byType(Container)).first,
      );
      final chips = tester.getRect(find.text('All (30)'));
      expect(
        chips.bottom,
        lessThanOrEqualTo(header.bottom),
        reason: 'filter chips are cropped - raise _HistoryHeaderDelegate._controlsH',
      );
    });

    testWidgets('search and filters stay pinned when scrolled at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value);

      // Scroll the collections table and a good part of the list away.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final search = find.text('Search invoice number or client');
      expect(search, findsOneWidget);
      expect(find.text('All (30)'), findsOneWidget);
      expect(tester.getRect(search).top, greaterThanOrEqualTo(0), reason: 'search box scrolled off screen');
    });
  }

  testWidgets('still renders with no bills at all', (tester) async {
    await _pumpAt(tester, phone, data: _appData(billCount: 0));

    expect(find.text('No bills yet'), findsOneWidget);
    expect(find.text("Today's Collections"), findsOneWidget);
  });

  testWidgets("a balance settled by card counts under Card in today's collections", (tester) async {
    // ₹590 bill: ₹200 by UPI at the counter, ₹390 cleared later by card.
    // The table used to credit the whole ₹590 to the bill's own method (UPI).
    final bill = Bill(
      id: 'b0',
      invoiceNumber: 'INV-0000',
      customerId: 'c1',
      customerName: 'Priya Ramakrishnan',
      branchId: 'br1',
      subTotal: 590,
      discountAmount: 0,
      taxAmount: 0,
      finalAmount: 590,
      paymentMethod: 'UPI',
      amountPaid: 590,
      laterPaymentsByMethod: const {'CARD': 390},
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      items: const [],
    );
    final data = _appData(billCount: 0);
    await _pumpAt(
      tester,
      phone,
      data: AppData(
        branches: data.branches,
        employees: data.employees,
        customers: data.customers,
        categories: data.categories,
        services: data.services,
        inventory: data.inventory,
        bills: [bill],
        discountRequests: data.discountRequests,
        salesTargets: data.salesTargets,
        commissions: data.commissions,
        attendance: data.attendance,
        dashboard: null,
        settings: null,
      ),
    );

    expect(find.text('₹390'), findsOneWidget); // Card
    expect(find.text('₹200'), findsOneWidget); // UPI
    expect(find.text('₹590'), findsWidgets); // total, and the bill row
  });
}
