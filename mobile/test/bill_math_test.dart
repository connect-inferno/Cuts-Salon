// Bills are whole rupees: the discount and GST amount are rounded, and the
// printed lines add up to the total exactly. computeBillTotals is shared by
// createBill and both billing screens, so these also pin the quote shown to
// the customer to the amount that gets stored.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/bill_math.dart';

void main() {
  test('the Instyle test bill comes out whole: 1300 - 10% + 18% GST = 1381', () {
    // Used to store ₹1,380.60 (GST ₹210.60) and show ₹1,381.
    final t = computeBillTotals(subTotal: 1300, discount: 130, gstRate: 18);
    expect(t.discount, 130);
    expect(t.taxable, 1170);
    expect(t.tax, 211);
    expect(t.total, 1381);
  });

  test('a fractional percentage discount rounds, and the lines still add up', () {
    // 10% of 1305 = 130.5 -> 131; GST 18% of 1174 = 211.32 -> 211.
    final t = computeBillTotals(subTotal: 1305, discount: 1305 * 0.10, gstRate: 18);
    expect(t.discount, 131);
    expect(t.tax, 211);
    expect(t.total, 1385);
    expect(t.subTotal - t.discount + t.tax, t.total);
  });

  test('no GST and no discount leaves the subtotal untouched', () {
    final t = computeBillTotals(subTotal: 700);
    expect(t.tax, 0);
    expect(t.total, 700);
  });

  test('a discount can never exceed the subtotal', () {
    final t = computeBillTotals(subTotal: 200, discount: 500, gstRate: 18);
    expect(t.discount, 200);
    expect(t.total, 0);
  });
}
