// A client's birthday is stored as "MM-DD" with no year (most clients won't
// give one, and the WhatsApp birthday message doesn't need it). That exact
// string is what functions/index.js matches on each morning, so everything
// that reads or writes one goes through these helpers.

const birthdayMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Days a birthday can fall on in [month] (1-12). February allows 29 - the
/// function wishes 29 Feb birthdays on 28 Feb in non-leap years.
int daysInBirthdayMonth(int month) {
  const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return days[month - 1];
}

String birthdayKey(int month, int day) =>
    '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

/// (month, day) from a stored "MM-DD", or null when absent or malformed.
(int, int)? parseBirthday(String? key) {
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 2) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  if (month == null || day == null || month < 1 || month > 12) return null;
  if (day < 1 || day > daysInBirthdayMonth(month)) return null;
  return (month, day);
}

/// "14 Oct", or null when there's no valid birthday.
String? formatBirthday(String? key) {
  final parsed = parseBirthday(key);
  if (parsed == null) return null;
  final (month, day) = parsed;
  return '$day ${birthdayMonthNames[month - 1]}';
}
