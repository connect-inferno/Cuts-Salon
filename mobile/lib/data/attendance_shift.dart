import 'models.dart';

/// How a shift is matched to a punch.
///
/// A shift belongs to the day it STARTED (its record is
/// "{employeeId}_{start date}"), and clock-out closes whichever shift is
/// still open - so someone who clocks in at 9 pm clocks out at 1 am onto
/// the same record, instead of being told they never clocked in "today".
///
/// A shift open for longer than [maxShiftLength] is treated as a forgotten
/// clock-out, not as still running: it shows as "no clock-out" in history,
/// it can no longer be clocked out (so a missed punch can't turn into a
/// 30-hour shift the next evening), and the person can clock in for a new
/// day. The owner corrects that day from the roster.
const maxShiftLength = Duration(hours: 16);

/// Clocked in, not out, and started within [maxShiftLength] of [now].
bool isOpenShift({DateTime? clockIn, DateTime? clockOut, required DateTime now}) =>
    clockIn != null && clockOut == null && now.difference(clockIn) < maxShiftLength;

/// The record a punch card should show for [employeeId]: the shift still
/// open (even if it started yesterday), otherwise today's record, otherwise
/// null.
AttendanceRecord? currentShiftRecord(Iterable<AttendanceRecord> records, String employeeId, DateTime now) {
  AttendanceRecord? today;
  AttendanceRecord? open;
  for (final r in records) {
    if (r.employeeId != employeeId) continue;
    if (isOpenShift(clockIn: r.clockIn, clockOut: r.clockOut, now: now)) {
      if (open == null || r.clockIn!.isAfter(open.clockIn!)) open = r;
    }
    final d = r.date;
    if (d != null && d.year == now.year && d.month == now.month && d.day == now.day) today = r;
  }
  return open ?? today;
}
