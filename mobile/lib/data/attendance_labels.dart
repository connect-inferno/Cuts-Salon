import 'attendance_shift.dart';
import 'models.dart';

/// Wording shared by every attendance history list (staff Attendance tab,
/// owner's attendance log, an employee's attendance sheet), so a day reads
/// the same wherever it is shown.

/// Stored status codes are never shown raw (see CLAUDE.md).
String attendanceStatusLabel(String status) {
  switch (status) {
    case 'PRESENT':
      return 'Present';
    case 'LATE':
      return 'Late';
    case 'ABSENT':
      return 'Absent';
    case 'LEAVE':
      return 'Leave';
    default:
      return status;
  }
}

/// "9:05 AM".
String formatClockTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour >= 12 ? 'PM' : 'AM'}';
}

/// "9h 5m", "45m".
String formatShiftLength(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 60) return '${minutes < 0 ? 0 : minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// The clock times of one day, or null when there are none (a day only
/// marked on the roster - nobody punched).
///
/// - both punches: "In 9:05 AM · Out 6:10 PM · 9h 5m"
/// - in, still open: "In 9:05 AM · on shift" (also a night shift that
///   started yesterday - see attendance_shift.dart)
/// - in, left open past [maxShiftLength]: "In 9:05 AM · no clock-out" -
///   they forgot, and the owner should see that rather than a day that
///   looks finished.
String? punchTimesLabel(AttendanceRecord rec, {DateTime? now}) {
  final clockIn = rec.clockIn;
  final clockOut = rec.clockOut;
  if (clockIn == null) return null;
  final inText = 'In ${formatClockTime(clockIn)}';
  if (clockOut != null) {
    return '$inText · Out ${formatClockTime(clockOut)} · ${formatShiftLength(clockOut.difference(clockIn))}';
  }
  final open = isOpenShift(clockIn: clockIn, clockOut: clockOut, now: now ?? DateTime.now());
  return '$inText · ${open ? 'on shift' : 'no clock-out'}';
}

/// Newest day first; on the same day, the later clock-in first, and a day
/// with no punch after the ones that have one.
int compareAttendanceNewestFirst(AttendanceRecord a, AttendanceRecord b) {
  final byDate = (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
  if (byDate != 0) return byDate;
  return (b.clockIn ?? DateTime(0)).compareTo(a.clockIn ?? DateTime(0));
}
