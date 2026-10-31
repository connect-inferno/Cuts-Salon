/// "₹25,000", "₹1,25,000" - rupees rounded to whole numbers with Indian
/// digit grouping. Plain toStringAsFixed(0) printed "₹25000", which is hard
/// to read at a glance; use this anywhere an amount is shown.
String formatInr(num amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  final whole = rounded.abs().toString();
  if (whole.length <= 3) return '$sign₹$whole';
  final last3 = whole.substring(whole.length - 3);
  final rest = whole
      .substring(0, whole.length - 3)
      .replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (m) => ',');
  return '$sign₹$rest,$last3';
}

/// "₹850", "₹12.5k", "₹1.2L", "₹2.4Cr" - for chart labels and axis ticks,
/// where a full "₹1,25,000" would not fit. Use [formatInr] everywhere else.
String formatInrCompact(num amount) {
  final sign = amount < 0 ? '-' : '';
  final v = amount.abs().toDouble();
  String trim(double x) => x >= 100 ? x.round().toString() : x.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  if (v >= 1e7) return '$sign₹${trim(v / 1e7)}Cr';
  if (v >= 1e5) return '$sign₹${trim(v / 1e5)}L';
  if (v >= 1e3) return '$sign₹${trim(v / 1e3)}k';
  return '$sign₹${v.round()}';
}
