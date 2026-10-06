/// A bill's totals, in whole rupees.
class BillTotals {
  final double subTotal;
  final double discount;
  final double taxable;
  final double tax;
  final double total;

  const BillTotals({
    required this.subTotal,
    required this.discount,
    required this.taxable,
    required this.tax,
    required this.total,
  });
}

/// The one place a bill's totals are worked out - used by
/// SalonFirestore.createBill when it writes the bill, and by both billing
/// screens to quote the customer, so the amount quoted is always the amount
/// stored.
///
/// Whole rupees: the discount and the GST amount are each rounded to the
/// nearest rupee (GST permits rounding the tax amount that way), so every
/// line printed on the bill is a whole number and subtotal - discount + GST
/// adds up to the total exactly, with no round-off line. Bills used to carry
/// paise (₹1,380.60) that every screen then rounded differently for display.
///
/// [subTotal] is only fractional if a catalogue price has paise; the total
/// is rounded too so the bill is still whole, at the cost of the lines then
/// being off by under a rupee in that one case.
BillTotals computeBillTotals({required double subTotal, double discount = 0, double gstRate = 0}) {
  final roundedDiscount = discount.clamp(0, subTotal).roundToDouble();
  final taxable = subTotal - roundedDiscount;
  final tax = (taxable * gstRate / 100).roundToDouble();
  return BillTotals(
    subTotal: subTotal,
    discount: roundedDiscount,
    taxable: taxable,
    tax: tax,
    total: (taxable + tax).roundToDouble(),
  );
}
