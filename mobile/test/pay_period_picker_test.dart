// The payroll period picker replaced two dropdowns that overflowed the
// dialog and happily offered months that had not happened yet. Both of those
// are invisible until someone runs payroll, so they are pinned here:
// the grid must fit the dialog at phone width, and a future month must be
// unselectable rather than merely unhelpful.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/widgets/pay_period_picker.dart';

// Mid-year, so there are future months in the current year and past months
// in both years - the interesting shape for these tests.
final _now = DateTime(2026, 9, 27);

Future<void> _pump(
  WidgetTester tester, {
  int month = 9,
  int year = 2026,
  void Function(int, int)? onChanged,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          // Roughly the width AppDialog gives its child - the box the old
          // dropdowns overflowed.
          child: SizedBox(
            width: 300,
            child: PayPeriodPicker(
              month: month,
              year: year,
              now: _now,
              onChanged: onChanged ?? (_, __) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all twelve months and both years at once', (tester) async {
    await _pump(tester);

    for (final m in const ['Jan', 'Jun', 'Sep', 'Dec']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('spells the chosen period out in full', (tester) async {
    await _pump(tester);
    // The grid shows "Sep"; a payroll run is not something to get wrong by
    // misreading a three-letter month.
    expect(find.text('Running for September 2026'), findsOneWidget);
  });

  testWidgets('a past month in the current year is selectable',
      (tester) async {
    int? gotMonth;
    int? gotYear;
    await _pump(tester, onChanged: (m, y) {
      gotMonth = m;
      gotYear = y;
    });

    await tester.tap(find.text('Mar'));
    await tester.pump();

    expect(gotMonth, 3);
    expect(gotYear, 2026);
  });

  testWidgets('the current month is selectable', (tester) async {
    int? gotMonth;
    await _pump(tester, month: 3, onChanged: (m, _) => gotMonth = m);

    await tester.tap(find.text('Sep'));
    await tester.pump();

    expect(gotMonth, 9);
  });

  testWidgets('a future month cannot be selected', (tester) async {
    var fired = false;
    await _pump(tester, onChanged: (_, __) => fired = true);

    // October onwards has not happened yet in September 2026. Payroll sums
    // what was earned, so these could only produce an empty record.
    for (final m in const ['Oct', 'Nov', 'Dec']) {
      await tester.tap(find.text(m));
      await tester.pump();
    }

    expect(fired, isFalse);
  });

  testWidgets('every month of a past year is selectable', (tester) async {
    final picked = <int>[];
    await _pump(tester, year: 2025, month: 1, onChanged: (m, _) => picked.add(m));

    for (final m in const ['Jan', 'Jun', 'Oct', 'Dec']) {
      await tester.tap(find.text(m));
      await tester.pump();
    }

    expect(picked, [1, 6, 10, 12]);
  });

  testWidgets('switching to the current year pulls a stranded month back',
      (tester) async {
    int? gotMonth;
    int? gotYear;
    // December 2025 is valid; December 2026 is not.
    await _pump(tester, month: 12, year: 2025, onChanged: (m, y) {
      gotMonth = m;
      gotYear = y;
    });

    await tester.tap(find.text('2026'));
    await tester.pump();

    expect(gotYear, 2026);
    // Clamped to the current month rather than left on a future December.
    expect(gotMonth, 9);
  });

  testWidgets('switching back to a past year keeps the month', (tester) async {
    int? gotMonth;
    int? gotYear;
    await _pump(tester, month: 3, year: 2026, onChanged: (m, y) {
      gotMonth = m;
      gotYear = y;
    });

    await tester.tap(find.text('2025'));
    await tester.pump();

    expect(gotYear, 2025);
    expect(gotMonth, 3);
  });

  testWidgets('fits the dialog without overflowing', (tester) async {
    // The whole reason this replaced the dropdowns: they ran 18px past the
    // edge once a long month name was showing.
    await _pump(tester, size: const Size(320, 640));
    expect(find.text('Dec'), findsOneWidget);

    await _pump(tester, size: const Size(375, 812));
    expect(find.text('Dec'), findsOneWidget);
  });
}
