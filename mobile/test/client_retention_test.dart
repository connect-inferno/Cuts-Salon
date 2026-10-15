// The Clients report answers "who comes back and who does not". The number
// that matters is the repeat rate, and the easiest way to get it wrong is the
// denominator - a salon that has just added forty clients it has not billed
// yet should not read as having lost them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/client_retention_report.dart';

final _now = DateTime(2026, 10, 1, 12);

Customer _client({
  required int visits,
  int? lastVisitDaysAgo,
  String id = 'c',
}) =>
    Customer(
      id: id,
      name: 'Client $id',
      phone: '9000000000',
      isVip: false,
      branchId: 'b1',
      visitCount: visits,
      lastVisitAt: lastVisitDaysAgo == null
          ? null
          : _now.subtract(Duration(days: lastVisitDaysAgo)),
    );

void main() {
  group('repeat rate', () {
    test('counts returning against those who have actually visited', () {
      final stats = computeRetention([
        _client(visits: 1, lastVisitDaysAgo: 2),
        _client(visits: 1, lastVisitDaysAgo: 3),
        _client(visits: 4, lastVisitDaysAgo: 4),
        _client(visits: 9, lastVisitDaysAgo: 5),
      ], _now);

      expect(stats.returning, 2);
      expect(stats.oneTime, 2);
      expect(stats.repeatRate, 0.5);
    });

    test('a client never billed is excluded from the rate, not counted against it',
        () {
      // Forty new names typed in on a quiet afternoon must not read as forty
      // clients who failed to come back.
      final stats = computeRetention([
        _client(visits: 2, lastVisitDaysAgo: 1),
        for (var i = 0; i < 40; i++) _client(visits: 0, id: 'new$i'),
      ], _now);

      expect(stats.never, 40);
      expect(stats.visited, 1);
      expect(stats.repeatRate, 1.0);
      expect(stats.total, 41);
    });

    test('no visits at all is 0%, not NaN and not 100%', () {
      final stats = computeRetention([
        _client(visits: 0),
        _client(visits: 0, id: 'c2'),
      ], _now);

      expect(stats.repeatRate, 0);
      expect(stats.visited, 0);
    });

    test('an empty salon does not divide by zero', () {
      final stats = computeRetention([], _now);
      expect(stats.repeatRate, 0);
      expect(stats.total, 0);
    });
  });

  group('visit-frequency ladder', () {
    test('buckets on the documented boundaries', () {
      final stats = computeRetention([
        _client(visits: 1, id: 'a'),
        _client(visits: 2, id: 'b'),
        _client(visits: 3, id: 'c'),
        _client(visits: 5, id: 'd'),
        _client(visits: 6, id: 'e'),
        _client(visits: 10, id: 'f'),
        _client(visits: 11, id: 'g'),
        _client(visits: 400, id: 'h'),
      ], _now);

      // 1 | 2 | 3-5 | 6-10 | 11+
      expect(stats.ladder, [1, 1, 2, 2, 2]);
    });

    test('never-visited clients are not on the ladder at all', () {
      final stats = computeRetention([
        _client(visits: 0),
        _client(visits: 1, id: 'b'),
      ], _now);

      expect(stats.ladder, [1, 0, 0, 0, 0]);
      expect(stats.ladder.fold<int>(0, (a, b) => a + b), stats.visited);
    });
  });

  group('follow-up groups', () {
    test('green from 30 days, yellow from 45, red from 60', () {
      RecencyBand? band(int daysAgo) =>
          recencyBandFor(_client(visits: 2, lastVisitDaysAgo: daysAgo), _now);

      expect(band(0), RecencyBand.active);
      expect(band(29), RecencyBand.active);
      expect(band(30), RecencyBand.green);
      expect(band(44), RecencyBand.green);
      expect(band(45), RecencyBand.yellow);
      expect(band(59), RecencyBand.yellow);
      expect(band(60), RecencyBand.red);
      expect(band(400), RecencyBand.red);
    });

    test('a client never billed is in no group', () {
      expect(recencyBandFor(_client(visits: 0), _now), isNull);
    });

    test('the four groups always account for everyone who has visited', () {
      final stats = computeRetention([
        _client(visits: 1, lastVisitDaysAgo: 1, id: 'a'),
        _client(visits: 2, lastVisitDaysAgo: 31, id: 'b'),
        _client(visits: 3, lastVisitDaysAgo: 50, id: 'c'),
        _client(visits: 3, lastVisitDaysAgo: 90, id: 'd'),
        _client(visits: 0, id: 'e'),
      ], _now);

      expect(stats.bands, [1, 1, 1, 1]);
      expect(stats.toContact, 3);
      expect(stats.bands.fold<int>(0, (a, b) => a + b), stats.visited);
    });

    test('the WhatsApp message uses the first name and the salon', () {
      final c = Customer(id: 'x', name: 'Ravi Kumar', phone: '9', isVip: false, branchId: 'b');
      final msg = winBackMessage(RecencyBand.red, c, 'Amits Salon');
      expect(msg, startsWith('Hi Ravi, we miss you at Amits Salon!'));
      expect(winBackMessage(RecencyBand.green, c, null), contains('the salon'));
    });
  });

  group('rendering', () {
    Future<void> pump(
      WidgetTester tester,
      List<Customer> customers, {
      Size size = const Size(375, 812),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClientRetentionReport(customers: customers, now: _now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the rate and both legends', (tester) async {
      await pump(tester, [
        _client(visits: 1, lastVisitDaysAgo: 2, id: 'a'),
        _client(visits: 5, lastVisitDaysAgo: 3, id: 'b'),
      ]);

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 of 2 came back'), findsOneWidget);
      expect(find.text('Returning'), findsOneWidget);
      expect(find.text('One visit only'), findsOneWidget);
    });

    testWidgets('an empty salon renders instead of throwing', (tester) async {
      // maxVal and the split bar both divide by counts that are zero here.
      await pump(tester, []);

      // The repeat rate, plus the chart legend's four 0% rows.
      expect(find.text('0%'), findsNWidgets(5));
      expect(find.text('Nobody in this group right now.'), findsOneWidget);
      expect(find.text('No one has been billed yet'), findsOneWidget);
    });

    testWidgets('lays out at a narrow width', (tester) async {
      await pump(
        tester,
        size: const Size(320, 640),
        [
          for (var i = 0; i < 30; i++)
            _client(visits: i % 13, lastVisitDaysAgo: i, id: 'c$i'),
        ],
      );

      expect(find.text('Visit Frequency'), findsOneWidget);
      expect(find.text('Client Follow-up'), findsOneWidget);
    });

    testWidgets('opens on the first group with anyone in it, and tapping a tile switches list', (tester) async {
      await pump(tester, size: const Size(375, 2000), [
        _client(visits: 2, lastVisitDaysAgo: 50, id: 'yellow'),
        _client(visits: 2, lastVisitDaysAgo: 70, id: 'red'),
      ]);

      // Nobody is green, so the yellow list shows first.
      expect(find.text('Slipping away · 1'), findsOneWidget);
      expect(find.text('Client yellow'), findsOneWidget);
      expect(find.text('Client red'), findsNothing);

      await tester.tap(find.text('At risk').last); // the tile, not the chart legend
      await tester.pumpAndSettle();
      expect(find.text('At risk · 1'), findsOneWidget);
      expect(find.text('Client red'), findsOneWidget);
    });
  });
}
