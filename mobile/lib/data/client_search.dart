import 'models.dart';

/// Digits only, with an Indian country code or trunk 0 dropped, so
/// "+91 98765-00002", "098765 00002" and "9876500002" all read the same.
String _phoneDigits(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

/// The one rule every client search box uses (Clients, staff Clients,
/// Dues, the Billing client picker):
///
/// * a number (at least 3 digits, spaces/+/- allowed) matches anywhere in
///   the client's mobile number, ignoring spaces, dashes and +91 - so the
///   last four digits a client reads out are enough;
/// * words match the name in any order and by their start or middle, so
///   "priya", "sharma priya" and "pri sha" all find "Priya Sharma";
/// * the email is searched too, when there is one.
bool customerMatchesQuery(Customer c, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;

  if (RegExp(r'^[\d\s+\-()]+$').hasMatch(q)) {
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) {
      final want = digits.length > 10 ? _phoneDigits(digits) : digits;
      return _phoneDigits(c.phone).contains(want);
    }
  }

  final name = c.name.toLowerCase();
  final email = c.email?.toLowerCase() ?? '';
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.every(name.contains)) return true;
  return email.isNotEmpty && email.contains(q);
}
