// The bill history header is a pinned, collapsing SliverPersistentHeader, and
// a pinned header has to declare its extents before it lays anything out - so
// the heights in _HistoryHeaderDelegate are hard-coded constants rather than
// measured. That is only safe while the widgets inside them actually fit.
//
// These tests pump the real view at a phone width and a tablet width, fully
// expanded and fully collapsed, and fail on any render overflow. If someone
// adds a line to a summary tile or bumps a font size, this is what catches it
// instead of an overflow stripe appearing on a salon's till.

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
    testWidgets('history header fits expanded at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value);

      // Expanded: the full tiles are showing, the compact strip is not.
      expect(find.text('Billed today'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);

      // The tiles are laid out unbounded and clipped, so too small a reserved
      // height crops them silently instead of throwing. Measure the tile card
      // itself, not its last line of text - the card's bottom padding and
      // border are part of what has to fit, and cropping those is visible.
      final clip = tester.getRect(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(ClipRect),
        ).first,
      );
      final card = tester.getRect(
        find.ancestor(
          of: find.text('Outstanding'),
          matching: find.byType(Container),
        ).first,
      );
      expect(
        card.bottom,
        lessThanOrEqualTo(clip.bottom),
        reason: 'summary tile is cropped - raise _HistoryHeaderDelegate._tilesH',
      );
    });

    testWidgets('history header fits collapsed at ${entry.key}', (tester) async {
      await _pumpAt(tester, entry.value);

      // Scroll well past the header's collapse range.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Collapsed: the strip has taken over, and - the actual point of the
      // change - the search box and filter chips are still on screen.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.text('Search invoice number or client'), findsOneWidget);
      expect(find.text('All (30)'), findsOneWidget);
    });
  }

  testWidgets('header still renders with no bills at all', (tester) async {
    await _pumpAt(tester, phone, data: _appData(billCount: 0));

    expect(find.text('No bills yet'), findsOneWidget);
    expect(find.text('Billed today'), findsOneWidget);
  });
}
