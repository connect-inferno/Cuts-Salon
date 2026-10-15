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
