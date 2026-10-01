// The owner's own punch. Three states, and the transitions between them are
// what decide whether a day's hours exist at all - so they are pinned here
// rather than left to be noticed on a Saturday when the owner worked and the
// app had no record of it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/owner_shift_card.dart';

final _now = DateTime(2026, 10, 1, 14, 30);

AttendanceRecord _record({DateTime? clockIn, DateTime? clockOut}) =>
    AttendanceRecord(
      id: 'a1',
      employeeId: 'owner1',
      date: DateTime(2026, 10, 1),
      clockIn: clockIn,
      clockOut: clockOut,
      status: clockIn == null ? 'ABSENT' : 'PRESENT',
    );

Future<void> _pump(
  WidgetTester tester, {
  AttendanceRecord? today,
  bool submitting = false,
  VoidCallback? onClockIn,
  VoidCallback? onClockOut,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OwnerShiftCard(
          today: today,
          submitting: submitting,
          now: _now,
          onClockIn: onClockIn ?? () {},
          onClockOut: onClockOut ?? () {},
        ),
      ),
    ),
  );
  // pump, not pumpAndSettle, while a punch is in flight: the button carries a
  // CircularProgressIndicator, which never stops animating and so never
  // settles.
  if (submitting) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  group('not punched yet', () {
    testWidgets('offers Clock In', (tester) async {
      await _pump(tester, today: null);

      expect(find.text('Not clocked in'), findsOneWidget);
      expect(find.text('Clock In'), findsOneWidget);
      expect(find.text('Clock Out'), findsNothing);
    });

    testWidgets('a record with no clock-in still offers Clock In',
        (tester) async {
      // The roster can write a status letter for a day before anyone punches,
      // so a record can exist with clockIn still null.
      await _pump(tester, today: _record());

      expect(find.text('Not clocked in'), findsOneWidget);
      expect(find.text('Clock In'), findsOneWidget);
    });

    testWidgets('tapping fires onClockIn', (tester) async {
      var fired = false;
      await _pump(tester, today: null, onClockIn: () => fired = true);

      await tester.tap(find.text('Clock In'));
      await tester.pump();

      expect(fired, isTrue);
    });
  });

  group('on shift', () {
    testWidgets('shows the start time and elapsed so far', (tester) async {
      await _pump(
        tester,
        today: _record(clockIn: DateTime(2026, 10, 1, 9, 42)),
      );

      expect(find.text('On shift'), findsOneWidget);
      // 09:42 to 14:30 is 4h 48m.
      expect(find.textContaining('Since 9:42 AM'), findsOneWidget);
      expect(find.textContaining('4h 48m so far'), findsOneWidget);
      expect(find.text('Clock Out'), findsOneWidget);
    });

    testWidgets('tapping fires onClockOut', (tester) async {
      var fired = false;
      await _pump(
        tester,
        today: _record(clockIn: DateTime(2026, 10, 1, 9, 0)),
        onClockOut: () => fired = true,
      );

      await tester.tap(find.text('Clock Out'));
      await tester.pump();

      expect(fired, isTrue);
    });
  });

  group('shift finished', () {
    testWidgets('shows both times and the total, with no button',
        (tester) async {
      await _pump(
        tester,
        today: _record(
          clockIn: DateTime(2026, 10, 1, 9, 42),
          clockOut: DateTime(2026, 10, 1, 18, 12),
        ),
      );

      expect(find.text('Shift finished'), findsOneWidget);
      expect(find.textContaining('9:42 AM - 6:12 PM'), findsOneWidget);
      expect(find.textContaining('8h 30m'), findsOneWidget);

      // No re-punch: a second clock-in would overwrite the day's clockIn and
      // lose the shift that was worked.
      expect(find.text('Clock In'), findsNothing);
      expect(find.text('Clock Out'), findsNothing);
      expect(find.text('Logged for today.'), findsOneWidget);
    });
  });

  testWidgets('a punch in flight disables the button', (tester) async {
    var fired = false;
    await _pump(
      tester,
      today: null,
      submitting: true,
      onClockIn: () => fired = true,
    );

    expect(find.text('Saving...'), findsOneWidget);
    // ElevatedButton.icon builds a private subclass, so byType misses it -
    // tap the label, which is what a thumb would hit anyway.
    await tester.tap(find.text('Saving...'));
    await tester.pump();
    expect(fired, isFalse);
  });

  group('formatting', () {
    test('midnight and noon do not read as 0 o\'clock', () {
      expect(OwnerShiftCard.formatTime(DateTime(2026, 10, 1, 0, 5)), '12:05 AM');
      expect(OwnerShiftCard.formatTime(DateTime(2026, 10, 1, 12, 5)), '12:05 PM');
    });

    test('minutes are padded', () {
      expect(OwnerShiftCard.formatTime(DateTime(2026, 10, 1, 9, 7)), '9:07 AM');
    });

    test('durations under an hour drop the hours part', () {
      expect(OwnerShiftCard.formatDuration(const Duration(minutes: 45)), '45m');
      expect(
        OwnerShiftCard.formatDuration(const Duration(hours: 2, minutes: 5)),
        '2h 5m',
      );
    });

    test('a negative span reads as zero rather than as minus time', () {
      // Clock skew between a till and the server should not render "-3m".
      expect(OwnerShiftCard.formatDuration(const Duration(minutes: -3)), '0m');
    });
  });

  testWidgets('lays out at a narrow width', (tester) async {
    await _pump(
      tester,
      size: const Size(320, 640),
      today: _record(
        clockIn: DateTime(2026, 10, 1, 9, 42),
        clockOut: DateTime(2026, 10, 1, 18, 12),
      ),
    );

    expect(find.text('Shift finished'), findsOneWidget);
  });
}
