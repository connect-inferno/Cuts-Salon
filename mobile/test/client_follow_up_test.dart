// The red/amber markers in the client directory are a business rule, not a
// piece of styling: a client is chased at 21 days since their last visit, and
// flagged amber for the two days before that. Getting a boundary wrong here
// means the salon either pesters someone who came in last week or never calls
// back someone who has drifted - and neither is visible by looking at the
// screen, because it depends on today's date.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/owner_customers_employees_tab.dart';

// A fixed "now" with a time of day on it, so the calendar-day arithmetic is
// actually exercised rather than accidentally passing on round numbers.
final _now = DateTime(2026, 9, 27, 14, 30);

Customer _client({DateTime? lastVisit}) => Customer(
      id: 'c1',
      name: 'Test Client',
      phone: '0000000000',
      isVip: false,
      branchId: 'br1',
      visitCount: lastVisit == null ? 0 : 3,
      lastVisitAt: lastVisit,
    );

Customer _visitedDaysAgo(int days, {int hour = 10}) {
  final d = _now.subtract(Duration(days: days));
  return _client(lastVisit: DateTime(d.year, d.month, d.day, hour));
}

void main() {
  group('followUpFor', () {
    test('a client who has never visited is never flagged', () {
      // Added to the directory but not yet billed: there is no visit to be
      // overdue from, so they must not appear as if they had lapsed.
      expect(followUpFor(_client(), _now), FollowUp.none);
    });

    test('a recent visit is not flagged', () {
      expect(followUpFor(_visitedDaysAgo(0), _now), FollowUp.none);
      expect(followUpFor(_visitedDaysAgo(7), _now), FollowUp.none);
    });

    test('amber starts exactly two days before the 21-day mark', () {
      // 18 days is still clear; 19 is the first amber day.
      expect(followUpFor(_visitedDaysAgo(18), _now), FollowUp.none);
      expect(followUpFor(_visitedDaysAgo(19), _now), FollowUp.dueSoon);
      expect(followUpFor(_visitedDaysAgo(20), _now), FollowUp.dueSoon);
    });

    test('red starts on the 21st day and stays red', () {
      expect(followUpFor(_visitedDaysAgo(21), _now), FollowUp.overdue);
      expect(followUpFor(_visitedDaysAgo(22), _now), FollowUp.overdue);
      expect(followUpFor(_visitedDaysAgo(400), _now), FollowUp.overdue);
    });

    test('the amber window is exactly kFollowUpWarningDays long', () {
      final amberDays = [
        for (var d = 0; d <= 30; d++)
          if (followUpFor(_visitedDaysAgo(d), _now) == FollowUp.dueSoon) d,
      ];
      expect(amberDays.length, kFollowUpWarningDays);
      expect(amberDays.last, kFollowUpDays - 1);
    });

    test('a future-dated visit is not flagged', () {
      // Clock skew between a till and the server shouldn't manufacture a
      // negative day count that trips a marker.
      final future = _now.add(const Duration(days: 3));
      expect(followUpFor(_client(lastVisit: future), _now), FollowUp.none);
    });
  });

  group('daysSinceVisit counts calendar days, not elapsed hours', () {
    test('late yesterday evening reads as 1 day ago the next morning', () {
      final morning = DateTime(2026, 9, 27, 8, 0);
      final lastNight = DateTime(2026, 9, 26, 23, 30);
      // Only 8.5 hours have elapsed, but anyone reading the screen calls
      // that yesterday.
      expect(daysSinceVisit(lastNight, morning), 1);
    });

    test('same day is zero whatever the hours between', () {
      expect(
        daysSinceVisit(DateTime(2026, 9, 27, 1), DateTime(2026, 9, 27, 23)),
        0,
      );
    });

    test('the 21-day boundary does not shift with time of day', () {
      // A visit at 9pm, checked at 7am 21 calendar days later: elapsed time
      // is under 21*24 hours, so a Duration-based count would say 20 and
      // silently delay the marker by a day.
      final visit = DateTime(2026, 9, 1, 21, 0);
      final check = DateTime(2026, 9, 22, 7, 0);
      expect(daysSinceVisit(visit, check), 21);
      expect(followUpFor(_client(lastVisit: visit), check), FollowUp.overdue);
    });
  });
}
