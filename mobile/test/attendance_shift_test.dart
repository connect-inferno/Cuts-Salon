import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/attendance_labels.dart';
import 'package:mobile/data/attendance_shift.dart';
import 'package:mobile/data/models.dart';

AttendanceRecord rec(String id, DateTime date, {DateTime? clockIn, DateTime? clockOut, String employeeId = 'e1'}) =>
    AttendanceRecord(id: id, employeeId: employeeId, date: date, clockIn: clockIn, clockOut: clockOut, status: 'PRESENT');

void main() {
  final yesterday = DateTime(2026, 10, 15);
  final today = DateTime(2026, 10, 16);

  group('night shift across midnight', () {
    final night = rec('y', yesterday, clockIn: DateTime(2026, 10, 15, 21, 0));
    final oneAm = DateTime(2026, 10, 16, 1, 0);

    test('is still the current shift after midnight', () {
      expect(currentShiftRecord([night], 'e1', oneAm)?.id, 'y');
      expect(punchTimesLabel(night, now: oneAm), 'In 9:00 PM · on shift');
    });

    test('closed after midnight shows the real length', () {
      final closed = rec('y', yesterday, clockIn: DateTime(2026, 10, 15, 21, 0), clockOut: DateTime(2026, 10, 16, 1, 30));
      expect(punchTimesLabel(closed, now: oneAm), 'In 9:00 PM · Out 1:30 AM · 4h 30m');
      // Closed, so the card falls through to today - nothing yet.
      expect(currentShiftRecord([closed], 'e1', oneAm), isNull);
    });
  });

  group('forgotten clock-out', () {
    final morning = rec('y', yesterday, clockIn: DateTime(2026, 10, 15, 9, 0));
    final nextMorning = DateTime(2026, 10, 16, 9, 30); // 24.5h later

    test('past the limit it is no longer open', () {
      expect(isOpenShift(clockIn: morning.clockIn, clockOut: null, now: nextMorning), isFalse);
      expect(currentShiftRecord([morning], 'e1', nextMorning), isNull);
      expect(punchTimesLabel(morning, now: nextMorning), 'In 9:00 AM · no clock-out');
    });

    test('just inside the limit it still is', () {
      final late = DateTime(2026, 10, 15, 9, 0).add(maxShiftLength - const Duration(minutes: 1));
      expect(isOpenShift(clockIn: morning.clockIn, clockOut: null, now: late), isTrue);
    });
  });

  test("today's finished shift is what the card shows", () {
    final done = rec('t', today, clockIn: DateTime(2026, 10, 16, 9), clockOut: DateTime(2026, 10, 16, 17));
    expect(currentShiftRecord([done], 'e1', DateTime(2026, 10, 16, 18))?.id, 't');
  });

  test("another employee's open shift is ignored", () {
    final theirs = rec('x', today, clockIn: DateTime(2026, 10, 16, 9), employeeId: 'e2');
    expect(currentShiftRecord([theirs], 'e1', DateTime(2026, 10, 16, 10)), isNull);
  });
}
