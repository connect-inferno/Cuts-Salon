import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/attendance_labels.dart';
import 'package:mobile/data/models.dart';

AttendanceRecord rec({
  String id = 'r',
  String employeeId = 'e1',
  required DateTime date,
  DateTime? clockIn,
  DateTime? clockOut,
  String status = 'PRESENT',
}) =>
    AttendanceRecord(id: id, employeeId: employeeId, date: date, clockIn: clockIn, clockOut: clockOut, status: status);

void main() {
  final now = DateTime(2026, 10, 16, 14, 0);
  final today = DateTime(2026, 10, 16);
  final yesterday = DateTime(2026, 10, 15);

  test('a finished shift shows in, out and hours', () {
    final r = rec(date: yesterday, clockIn: DateTime(2026, 10, 15, 9, 5), clockOut: DateTime(2026, 10, 15, 18, 10));
    expect(punchTimesLabel(r, now: now), 'In 9:05 AM · Out 6:10 PM · 9h 5m');
  });

  test('today with no clock-out is still on shift', () {
    final r = rec(date: today, clockIn: DateTime(2026, 10, 16, 10, 0));
    expect(punchTimesLabel(r, now: now), 'In 10:00 AM · on shift');
  });

  test('a past day with no clock-out says so', () {
    final r = rec(date: yesterday, clockIn: DateTime(2026, 10, 15, 10, 0));
    expect(punchTimesLabel(r, now: now), 'In 10:00 AM · no clock-out');
  });

  test('a roster-only day has no times', () {
    expect(punchTimesLabel(rec(date: yesterday, status: 'LEAVE'), now: now), isNull);
  });

  test('times around noon and midnight', () {
    expect(formatClockTime(DateTime(2026, 1, 1, 0, 7)), '12:07 AM');
    expect(formatClockTime(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(formatClockTime(DateTime(2026, 1, 1, 23, 59)), '11:59 PM');
  });

  test('shift lengths', () {
    expect(formatShiftLength(const Duration(minutes: 45)), '45m');
    expect(formatShiftLength(const Duration(hours: 8)), '8h');
    expect(formatShiftLength(const Duration(hours: 8, minutes: 30)), '8h 30m');
    expect(formatShiftLength(const Duration(minutes: -3)), '0m');
  });

  test('status codes read as words', () {
    expect(attendanceStatusLabel('PRESENT'), 'Present');
    expect(attendanceStatusLabel('LATE'), 'Late');
    expect(attendanceStatusLabel('ABSENT'), 'Absent');
    expect(attendanceStatusLabel('LEAVE'), 'Leave');
  });

  test('newest day first, later clock-in first within a day', () {
    final a = rec(id: 'a', date: yesterday, clockIn: DateTime(2026, 10, 15, 9));
    final b = rec(id: 'b', date: today, clockIn: DateTime(2026, 10, 16, 9));
    final c = rec(id: 'c', date: today, clockIn: DateTime(2026, 10, 16, 11));
    final d = rec(id: 'd', date: today, status: 'ABSENT');
    final sorted = [a, d, b, c]..sort(compareAttendanceNewestFirst);
    expect(sorted.map((r) => r.id), ['c', 'b', 'd', 'a']);
  });
}
