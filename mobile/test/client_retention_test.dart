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

  group('follow-up standing', () {
    test('uses the same 21-day rule as the client list markers', () {
      final stats = computeRetention([
        _client(visits: 3, lastVisitDaysAgo: 5, id: 'fresh'),
        _client(visits: 3, lastVisitDaysAgo: 18, id: 'stillok'),
        _client(visits: 3, lastVisitDaysAgo: 19, id: 'duesoon'),
        _client(visits: 3, lastVisitDaysAgo: 20, id: 'duesoon2'),
        _client(visits: 3, lastVisitDaysAgo: 21, id: 'overdue'),
        _client(visits: 3, lastVisitDaysAgo: 90, id: 'longgone'),
      ], _now);

      expect(stats.active, 2);
      expect(stats.dueSoon, 2);
      expect(stats.overdue, 2);
    });

    test('the three buckets always account for everyone who has visited', () {
      final stats = computeRetention([
        _client(visits: 1, lastVisitDaysAgo: 1, id: 'a'),
        _client(visits: 2, lastVisitDaysAgo: 19, id: 'b'),
        _client(visits: 3, lastVisitDaysAgo: 40, id: 'c'),
        _client(visits: 0, id: 'd'),
      ], _now);

      expect(stats.active + stats.dueSoon + stats.overdue, stats.visited);
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

      expect(find.text('0%'), findsOneWidget);
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
      expect(find.text('Follow-up Standing'), findsOneWidget);
    });
  });
}
