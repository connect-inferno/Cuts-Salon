/// A client's phone as the app stores it: the 10-digit Indian mobile number,
/// or null when [raw] isn't one.
///
/// Accepts the ways people type it - spaces, dashes, brackets, a +91 / 91 /
/// 0 in front - and keeps only the 10 digits, so "+91 98765 43210" and
/// "9876543210" are the same client (and the duplicate check sees that).
/// An Indian mobile starts with 6-9. Same test as normalizePhone in
/// functions/whatsapp_core.js, so every number saved here can be messaged.
String? indianMobile(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || RegExp(r'[^\d\s\-+().]').hasMatch(trimmed)) return null;
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
}
