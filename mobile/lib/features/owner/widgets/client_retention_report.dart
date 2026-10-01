import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models.dart';
import '../../../theme.dart';
import 'owner_customers_employees_tab.dart' show FollowUp, followUpFor, kFollowUpDays;

/// Retention, counted once so every card on the Clients report agrees.
///
/// Derived from the customer documents rather than from bills, deliberately.
/// `AppData.bills` is capped by the read-reduction work, so counting visits
/// from it would quietly undercount anyone whose visits fell outside the
/// window that happened to be loaded. `visitCount` and `lastVisitAt` are
/// denormalized onto the customer document by every bill
/// (see SalonFirestore.createBill), so they are complete and already loaded.
///
/// The consequence, which the report says out loud: these are lifetime
/// figures. They do not narrow with the page's timeframe pill, because a
/// client's visit count is not a per-period number.
class ClientRetentionStats {
  /// On the books but never billed. Counted apart from everyone else: a
  /// client who has not started is not a client who failed to come back, and
  /// folding them into the repeat rate would drag it down for doing nothing
  /// worse than being new.
  final int never;
  final int oneTime;
  final int returning;

  /// Visit-count buckets, in [ladderLabels] order.
  final List<int> ladder;

  /// Follow-up standing, using the same 21-day rule as the markers in the
  /// client directory - so the report and the list cannot disagree about who
  /// is overdue.
  final int active;
  final int dueSoon;
  final int overdue;

  const ClientRetentionStats({
    required this.never,
    required this.oneTime,
    required this.returning,
    required this.ladder,
    required this.active,
    required this.dueSoon,
    required this.overdue,
  });

  static const ladderLabels = ['1', '2', '3-5', '6-10', '11+'];

  /// Clients who have actually been in at least once.
  int get visited => oneTime + returning;

  int get total => never + visited;

  /// Share of clients who came back, out of those who ever came at all.
  /// Zero when nobody has visited yet - not NaN, and not 100%.
  double get repeatRate => visited == 0 ? 0 : returning / visited;
}

ClientRetentionStats computeRetention(List<Customer> customers, DateTime now) {
  var never = 0, oneTime = 0, returning = 0;
  var active = 0, dueSoon = 0, overdue = 0;
  final ladder = [0, 0, 0, 0, 0];

  for (final c in customers) {
    final v = c.visitCount;
    if (v <= 0) {
      never++;
      continue;
    }
    if (v == 1) {
      oneTime++;
    } else {
      returning++;
    }

    if (v == 1) {
      ladder[0]++;
    } else if (v == 2) {
      ladder[1]++;
    } else if (v <= 5) {
      ladder[2]++;
    } else if (v <= 10) {
      ladder[3]++;
    } else {
      ladder[4]++;
    }

    switch (followUpFor(c, now)) {
      case FollowUp.overdue:
        overdue++;
      case FollowUp.dueSoon:
        dueSoon++;
      case FollowUp.none:
        active++;
    }
  }

  return ClientRetentionStats(
    never: never,
    oneTime: oneTime,
    returning: returning,
    ladder: ladder,
    active: active,
    dueSoon: dueSoon,
    overdue: overdue,
  );
}

/// The Clients segment of the owner's reports.
///
/// Answers "who comes back and who does not" in three steps: the headline
/// rate, how deep the loyalty goes, and who is slipping away right now.
class ClientRetentionReport extends StatelessWidget {
  final List<Customer> customers;

  /// Passed in rather than read from the clock so every card in one build
  /// agrees on where the 21-day line falls.
  final DateTime now;

  const ClientRetentionReport({
    super.key,
    required this.customers,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final s = computeRetention(customers, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _repeatRateCard(s),
        const SizedBox(height: 14),
        _ladderCard(s),
        const SizedBox(height: 14),
        _followUpCard(s),
      ],
    );
  }

  // ─── shared card chrome, matching the other report cards ───────────────
  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: child,
      );

  Widget _cardHeader(String title, String subtitle, {String? badge}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ],
      );

  // ─── 1. the headline ───────────────────────────────────────────────────
  Widget _repeatRateCard(ClientRetentionStats s) {
    final pct = (s.repeatRate * 100).round();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            'Repeat Rate',
            'Of clients who have been in at least once',
            badge: 'All time',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    s.visited == 0
                        ? 'No one has been billed yet'
                        : '${s.returning} of ${s.visited} came back',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // One bar, split. The two numbers are parts of the same whole, so
          // showing them as two separate bars would invite reading them as
          // unrelated totals.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: s.returning == 0 ? 0 : s.returning,
                    child: Container(color: AppTheme.accentGreen),
                  ),
                  Expanded(
                    flex: s.oneTime == 0 ? 0 : s.oneTime,
                    child: Container(color: AppTheme.accentAmber),
                  ),
                  // Keeps the bar from collapsing to nothing before anyone
                  // has visited.
                  if (s.visited == 0)
                    const Expanded(
                      child: ColoredBox(color: Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _legend(
                  AppTheme.accentGreen,
                  'Returning',
                  '${s.returning}',
                ),
              ),
              Expanded(
                child: _legend(
                  AppTheme.accentAmber,
                  'One visit only',
                  '${s.oneTime}',
                ),
              ),
              if (s.never > 0)
                Expanded(
                  child: _legend(
                    const Color(0xFFCBD5E1),
                    'Not yet billed',
                    '${s.never}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ─── 2. how deep the loyalty goes ──────────────────────────────────────
  Widget _ladderCard(ClientRetentionStats s) {
    final maxVal = s.ladder.fold<int>(1, (m, v) => v > m ? v : m);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            'Visit Frequency',
            'How many clients sit at each number of visits',
            badge: 'All time',
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < s.ladder.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${s.ladder[i]}',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            // Floor of 4px so an empty bucket still reads as
                            // a bucket rather than vanishing from the axis.
                            height: 4 + (s.ladder[i] / maxVal) * 86,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: i == 0
                                    // The one-visit bucket is the problem
                                    // bucket, so it is not drawn in the same
                                    // colour as the loyal ones.
                                    ? [
                                        AppTheme.accentAmber,
                                        const Color(0xFFFBBF24),
                                      ]
                                    : [
                                        AppTheme.primaryBlue,
                                        const Color(0xFF6366F1),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ClientRetentionStats.ladderLabels[i],
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visits per client',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. who is slipping away ───────────────────────────────────────────
  Widget _followUpCard(ClientRetentionStats s) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            'Follow-up Standing',
            'Counted from each client\'s last visit, on the same '
            '$kFollowUpDays-day rule as the markers in the client list',
          ),
          const SizedBox(height: 16),
          _followUpRow(
            color: AppTheme.accentGreen,
            bg: AppTheme.accentGreenBg,
            icon: PhosphorIconsBold.checkCircle,
            label: 'On schedule',
            detail: 'Seen within the last ${kFollowUpDays - 2} days',
            count: s.active,
            total: s.visited,
          ),
          const SizedBox(height: 10),
          _followUpRow(
            color: AppTheme.accentAmber,
            bg: AppTheme.accentAmberBg,
            icon: PhosphorIconsBold.clockCountdown,
            label: 'Due soon',
            detail: 'Hitting $kFollowUpDays days within two',
            count: s.dueSoon,
            total: s.visited,
          ),
          const SizedBox(height: 10),
          _followUpRow(
            color: const Color(0xFFDC2626),
            bg: const Color(0xFFFEF2F2),
            icon: PhosphorIconsBold.warningCircle,
            label: 'Overdue',
            detail: 'Past $kFollowUpDays days with no return',
            count: s.overdue,
            total: s.visited,
          ),
        ],
      ),
    );
  }

  Widget _followUpRow({
    required Color color,
    required Color bg,
    required IconData icon,
    required String label,
    required String detail,
    required int count,
    required int total,
  }) {
    final share = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
