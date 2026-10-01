// The payment breakdown has to agree with the figures on Home, and the two
// easy ways to get it wrong are both about money going missing: dropping the
// amount collected up front on a pay-later bill, and treating the amount
// still owed as though it were a payment method.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/payment_method_report.dart';

Bill _bill({
  required String method,
  required double total,
  double? paid,
  String id = 'b',
}) =>
    Bill(
      id: id,
      invoiceNumber: 'INV-$id',
      customerId: 'c1',
      branchId: 'br1',
      subTotal: total,
      discountAmount: 0,
      taxAmount: 0,
      finalAmount: total,
      paymentMethod: method,
      amountPaid: paid ?? total,
      status: 'COMPLETED',
      createdAt: DateTime(2026, 10, 1),
      items: const [],
    );

String _inr(double v) => '₹${v.round()}';

void main() {
  group('computePaymentMix', () {
    test('groups collected takings by method', () {
      final mix = computePaymentMix([
        _bill(method: 'CASH', total: 500, id: 'a'),
        _bill(method: 'CASH', total: 300, id: 'b'),
        _bill(method: 'UPI', total: 1000, id: 'c'),
        _bill(method: 'CARD', total: 200, id: 'd'),
      ]);

      expect(mix.cash, 800);
      expect(mix.upi, 1000);
      expect(mix.card, 200);
      expect(mix.cashBills, 2);
      expect(mix.collected, 2000);
    });

    test('money taken up front on a pay-later bill is still counted', () {
      // The bill's method is PENDING, so attributing this to cash or UPI
      // would invent detail the record does not carry - but dropping it
      // would lose real money out of the total.
      final mix = computePaymentMix([
        _bill(method: 'PENDING', total: 1000, paid: 400, id: 'a'),
      ]);

      expect(mix.payLater, 400);
      expect(mix.collected, 400);
      expect(mix.outstanding, 600);
    });

    test('outstanding is counted but is not a payment method', () {
      final mix = computePaymentMix([
        _bill(method: 'CASH', total: 1000, paid: 1000, id: 'a'),
        _bill(method: 'PENDING', total: 500, paid: 0, id: 'b'),
      ]);

      expect(mix.collected, 1000);
      expect(mix.outstanding, 500);
      // The shares are of what came in, not of what was billed.
      expect(mix.shareOf(mix.cash), 1.0);
    });

    test('a bill that collected nothing adds no row', () {
      final mix = computePaymentMix([
        _bill(method: 'PENDING', total: 800, paid: 0, id: 'a'),
      ]);

      expect(mix.payLaterBills, 0);
      expect(mix.collected, 0);
    });

    test('an unknown method is counted rather than silently dropped', () {
      // If a method is ever added without this switch being updated, the
      // total must still be right.
      final mix = computePaymentMix([
        _bill(method: 'WALLET', total: 250, id: 'a'),
      ]);

      expect(mix.collected, 250);
    });

    test('shares do not divide by zero on an empty window', () {
      final mix = computePaymentMix([]);
      expect(mix.collected, 0);
      expect(mix.shareOf(0), 0);
    });

    test('the parts always add up to the collected total', () {
      final mix = computePaymentMix([
        _bill(method: 'CASH', total: 100, id: 'a'),
        _bill(method: 'UPI', total: 200, id: 'b'),
        _bill(method: 'CARD', total: 300, id: 'c'),
        _bill(method: 'PENDING', total: 900, paid: 400, id: 'd'),
      ]);

      expect(mix.cash + mix.upi + mix.card + mix.payLater, mix.collected);
    });
  });

  group('rendering', () {
    Future<void> pump(
      WidgetTester tester,
      List<Bill> bills, {
      Size size = const Size(375, 812),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentMethodReport(bills: bills, formatCurrency: _inr),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists all three methods by name', (tester) async {
      await pump(tester, [
        _bill(method: 'CASH', total: 800, id: 'a'),
        _bill(method: 'UPI', total: 1200, id: 'b'),
      ]);

      // Readable labels, not the stored CASH/UPI values - and Card is listed
      // even with no takings, so "none this month" is distinguishable from
      // "not a thing here".
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI / QR'), findsOneWidget);
      expect(find.text('Card / POS'), findsOneWidget);
      expect(find.text('No longer offered'), findsOneWidget);
    });

    testWidgets('shows shares and bill counts', (tester) async {
      await pump(tester, [
        _bill(method: 'CASH', total: 750, id: 'a'),
        _bill(method: 'UPI', total: 250, id: 'b'),
      ]);

      expect(find.text('₹1000'), findsOneWidget); // collected
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('1 bill'), findsNWidgets(2));
    });

    testWidgets('an empty window renders instead of throwing', (tester) async {
      await pump(tester, []);
      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
    });

    testWidgets('surfaces what is still owed', (tester) async {
      await pump(tester, [
        _bill(method: 'PENDING', total: 1000, paid: 200, id: 'a'),
      ]);

      expect(
        find.textContaining('still outstanding'),
        findsOneWidget,
      );
    });

    testWidgets('lays out at a narrow width', (tester) async {
      await pump(
        tester,
        size: const Size(320, 640),
        [
          _bill(method: 'CASH', total: 1234567, id: 'a'),
          _bill(method: 'PENDING', total: 9000, paid: 4500, id: 'b'),
        ],
      );

      expect(find.text('Cash'), findsOneWidget);
    });
  });
}
