import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models.dart';
import '../../../data/money.dart';
import '../../../theme.dart';
import '../../../widgets/ds.dart';
import '../../../widgets/open_link.dart';
import 'owner_customers_employees_tab.dart' show daysSinceVisit;

/// How long since a client was last in, in the three follow-up groups the
/// owner works through on the Clients report:
///
/// * green  - 30 to 44 days: due for their next visit, a friendly reminder;
/// * yellow - 45 to 59 days: slipping away, ask when they'd like to come in;
/// * red    - 60 days or more: at risk of being lost, a personal call.
///
/// Under 30 days is [active] and needs nothing. These are the usual salon
/// "lapsed client" bands (most hair services are rebooked within 4-6
/// weeks). They are separate from the 21-day dot in the client list, which
/// is the short haircut-cycle nudge the automatic WhatsApp reminder also
/// uses; this report is the longer win-back view.
enum RecencyBand { active, green, yellow, red }

const int kRecencyGreenDays = 30;
const int kRecencyYellowDays = 45;
const int kRecencyRedDays = 60;

/// null for a client who has never been billed: there is no visit to count
/// from, and someone who has not started is not someone who drifted away.
RecencyBand? recencyBandFor(Customer c, DateTime now) {
  final last = c.lastVisitAt;
  if (last == null || c.visitCount <= 0) return null;
  final days = daysSinceVisit(last, now);
  if (days >= kRecencyRedDays) return RecencyBand.red;
  if (days >= kRecencyYellowDays) return RecencyBand.yellow;
  if (days >= kRecencyGreenDays) return RecencyBand.green;
  return RecencyBand.active;
}

/// Colour, wording and the ready-written WhatsApp message for each group,
/// in one place so the chart, the tiles and the list cannot disagree.
class RecencyBandInfo {
  final String name;
  final String range;
  final String advice;
  final Color color;
  final Color bg;

  const RecencyBandInfo(this.name, this.range, this.advice, this.color, this.bg);

  static RecencyBandInfo of(RecencyBand band) => switch (band) {
        RecencyBand.active => const RecencyBandInfo(
            'Active', 'Under 30 days', 'Visited recently - nothing to do.',
            AppTheme.primaryBlue, AppTheme.primaryLight),
        RecencyBand.green => const RecencyBandInfo(
            'Due for a visit', '30-44 days',
            'About a month since they came in. A friendly reminder usually brings them back.',
            AppTheme.accentGreen, AppTheme.accentGreenBg),
        RecencyBand.yellow => const RecencyBandInfo(
            'Slipping away', '45-59 days',
            'Six weeks or more. Ask when they would like to come in next.',
            AppTheme.accentAmber, AppTheme.accentAmberBg),
        RecencyBand.red => const RecencyBandInfo(
            'At risk', '60+ days',
            'Two months or more - they may be going elsewhere. A personal call works best.',
            AppTheme.accentRed, AppTheme.accentRedBg),
      };
}

/// The WhatsApp text for a client in [band]. The staff member reads it in
/// WhatsApp and presses send - nothing goes out on its own from here.
String winBackMessage(RecencyBand band, Customer c, String? salonName) {
  final first = c.name.trim().split(RegExp(r'\s+')).first;
  final salon = (salonName == null || salonName.trim().isEmpty) ? 'the salon' : salonName.trim();
  const ask = 'When would you like to come in next? Reply here and we will book a time that suits you.';
  return switch (band) {
    RecencyBand.red => 'Hi $first, we miss you at $salon! It has been a while since your last visit. $ask',
    RecencyBand.yellow => "Hi $first, we haven't seen you at $salon for a few weeks. $ask",
    _ => 'Hi $first, it has been about a month since your last visit to $salon. $ask',
  };
}

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

  /// Clients in each [RecencyBand], indexed by the enum.
  final List<int> bands;

  const ClientRetentionStats({
    required this.never,
    required this.oneTime,
    required this.returning,
    required this.ladder,
    required this.bands,
  });

  static const ladderLabels = ['1', '2', '3-5', '6-10', '11+'];

  /// Clients who have actually been in at least once.
  int get visited => oneTime + returning;

  int get total => never + visited;

  int count(RecencyBand band) => bands[band.index];

  /// Everyone in the green, yellow and red groups.
  int get toContact => count(RecencyBand.green) + count(RecencyBand.yellow) + count(RecencyBand.red);

  /// Share of clients who came back, out of those who ever came at all.
  /// Zero when nobody has visited yet - not NaN, and not 100%.
  double get repeatRate => visited == 0 ? 0 : returning / visited;
}

ClientRetentionStats computeRetention(List<Customer> customers, DateTime now) {
  var never = 0, oneTime = 0, returning = 0;
  final ladder = [0, 0, 0, 0, 0];
  final bands = [0, 0, 0, 0];

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

    // A visit count with no date (data from before lastVisitAt existed)
    // counts as active rather than being dropped, so the four groups always
    // add up to everyone who has visited.
    bands[(recencyBandFor(c, now) ?? RecencyBand.active).index]++;
  }

  return ClientRetentionStats(
    never: never,
    oneTime: oneTime,
    returning: returning,
    ladder: ladder,
    bands: bands,
  );
}

/// The Clients segment of the owner's reports.
///
/// Leads with who to get back in touch with - a chart of everyone by how
/// long since their last visit, then the green / yellow / red follow-up
/// lists with Call and WhatsApp on every row - and below that the longer
/// view: repeat rate and how deep the loyalty goes.
class ClientRetentionReport extends StatefulWidget {
  final List<Customer> customers;

  /// Passed in rather than read from the clock so every card in one build
  /// agrees on where the day lines fall.
  final DateTime now;

  /// Signs the WhatsApp messages ("we miss you at ...").
  final String? salonName;

  /// Opens a client's page when their row is tapped.
  final void Function(Customer)? onOpenClient;

  /// Just the three follow-up groups and their list - Reports' Clients
  /// section shows its own summary above it.
  final bool compact;

  const ClientRetentionReport({
    super.key,
    required this.customers,
    required this.now,
    this.salonName,
    this.onOpenClient,
    this.compact = false,
  });

  @override
  State<ClientRetentionReport> createState() => _ClientRetentionReportState();
}

class _ClientRetentionReportState extends State<ClientRetentionReport> {
  /// Long lists show this many rows until "Show all" is tapped.
  static const _kPreviewRows = 15;

  /// null until the owner picks one: then the first group with anyone in it.
  RecencyBand? _picked;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final s = computeRetention(widget.customers, widget.now);
    const followUpBands = [RecencyBand.green, RecencyBand.yellow, RecencyBand.red];
    final selected = _picked ??
        followUpBands.firstWhere((b) => s.count(b) > 0, orElse: () => RecencyBand.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          _overviewCard(s),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            for (final b in followUpBands) ...[
              if (b != RecencyBand.green) const SizedBox(width: 8),
              Expanded(child: _bandTile(b, s.count(b), b == selected)),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _followUpList(selected),
        if (!widget.compact) ...[
          const SizedBox(height: 14),
          _repeatRateCard(s),
          const SizedBox(height: 14),
          _ladderCard(s),
        ],
      ],
    );
  }

  // ─── shared card chrome, matching the other report cards ───────────────
  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: AppTheme.cardShadow,
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
                    fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w700,
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
                              // The one-visit bucket is the problem bucket,
                              // so it is not drawn in the same colour as the
                              // loyal ones. Flat fills: no gradients.
                              color: i == 0 ? AppTheme.accentAmber : AppTheme.primaryBlue,
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

  // ─── 1. everyone, by days since their last visit ───────────────────────
  Widget _overviewCard(ClientRetentionStats s) {
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in RecencyBand.values) ...[
          if (b != RecencyBand.active) const SizedBox(height: 10),
          _overviewLegendRow(b, s.count(b), s.visited),
        ],
      ],
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            'Client Follow-up',
            'Everyone who has visited, by days since their last visit',
            badge: 'Today',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, c) {
            final donut = _RecencyDonut(stats: s);
            // Side by side when there is room, stacked on a narrow phone.
            if (c.maxWidth < 330) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Center(child: donut), const SizedBox(height: 18), legend],
              );
            }
            return Row(
              children: [donut, const SizedBox(width: 20), Expanded(child: legend)],
            );
          }),
        ],
      ),
    );
  }

  Widget _overviewLegendRow(RecencyBand band, int count, int total) {
    final info = RecencyBandInfo.of(band);
    final pct = total == 0 ? 0 : (count * 100 / total).round();
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
              Text(info.range,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppTheme.slateLight)),
            ],
          ),
        ),
        Text('$count',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.slateDark)),
        SizedBox(
          width: 40,
          child: Text('$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
        ),
      ],
    );
  }

  // ─── 2. the three follow-up groups ─────────────────────────────────────
  Widget _bandTile(RecencyBand band, int count, bool selected) {
    final info = RecencyBandInfo.of(band);
    return Material(
      color: selected ? info.bg : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _picked = band;
          _showAll = false;
        }),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? info.color : AppTheme.borderSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(info.range,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: info.color)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.slateDark, letterSpacing: -0.5)),
              Text(info.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
            ],
          ),
        ),
      ),
    );
  }

  /// The selected group's clients, top spenders first - with the same
  /// number of calls to make, the best clients are the ones to reach first.
  Widget _followUpList(RecencyBand band) {
    final info = RecencyBandInfo.of(band);
    final clients = widget.customers.where((c) => recencyBandFor(c, widget.now) == band).toList()
      ..sort((a, b) {
        final bySpend = b.totalSpent.compareTo(a.totalSpent);
        return bySpend != 0 ? bySpend : a.lastVisitAt!.compareTo(b.lastVisitAt!);
      });
    final shown = _showAll ? clients : clients.take(_kPreviewRows).toList();

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${info.name} · ${clients.length}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.slateDark),
                      ),
                    ),
                    DsPill(info.range, color: info.color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  clients.isEmpty ? 'Nobody in this group right now.' : '${info.advice} Top spenders first.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.slateLight, height: 1.4),
                ),
              ],
            ),
          ),
          for (var i = 0; i < shown.length; i++) ...[
            const Divider(height: 1, color: AppTheme.borderSubtle),
            _clientRow(band, shown[i]),
          ],
          if (clients.length > shown.length) ...[
            const Divider(height: 1, color: AppTheme.borderSubtle),
            TextButton(
              onPressed: () => setState(() => _showAll = true),
              child: Text('Show all ${clients.length}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clientRow(RecencyBand band, Customer c) {
    final days = daysSinceVisit(c.lastVisitAt!, widget.now);
    final visits = '${c.visitCount} visit${c.visitCount == 1 ? '' : 's'}';
    return DsListRow(
      leading: DsAvatar(c.name),
      title: c.name,
      subtitle: '$days days ago · $visits · ${formatInr(c.totalSpent)}',
      onTap: widget.onOpenClient == null ? null : () => widget.onOpenClient!(c),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundAction(
            icon: PhosphorIconsRegular.whatsappLogo,
            tooltip: 'Message on WhatsApp',
            onTap: () => _message(band, c),
          ),
          const SizedBox(width: 6),
          _roundAction(
            icon: PhosphorIconsRegular.phone,
            tooltip: 'Call',
            onTap: () => _call(c),
          ),
        ],
      ),
    );
  }

  Widget _roundAction({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.primaryLight,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: AppTheme.primaryBlue),
          ),
        ),
      ),
    );
  }

  /// Opens a WhatsApp chat with the message already written; the person
  /// reads it and presses send themselves.
  void _message(RecencyBand band, Customer c) {
    final number = whatsappNumber(c.phone);
    final text = Uri.encodeComponent(winBackMessage(band, c, widget.salonName));
    if (number == null || !openLink('https://wa.me/$number?text=$text')) {
      _failed('${c.phone} does not look like a WhatsApp number.');
    }
  }

  void _call(Customer c) {
    final number = c.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (number.isEmpty || !openLink('tel:$number')) {
      _failed('Could not start a call to ${c.phone}.');
    }
  }

  void _failed(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.accentRed, behavior: SnackBarBehavior.floating),
    );
  }
}

/// A ring split into the four groups, with how many to contact in the
/// middle. Gaps between segments keep neighbouring colours apart.
class _RecencyDonut extends StatelessWidget {
  final ClientRetentionStats stats;

  const _RecencyDonut({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: CustomPaint(
        painter: _DonutPainter([
          for (final b in RecencyBand.values) (stats.count(b), RecencyBandInfo.of(b).color),
        ]),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${stats.toContact}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.slateDark, letterSpacing: -0.8)),
              const Text('to contact',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slateLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(int, Color)> segments;

  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final total = segments.fold<int>(0, (s, e) => s + e.$1);
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = const Color(0xFFE2E8F0));
      return;
    }
    final drawn = segments.where((e) => e.$1 > 0).toList();
    final gap = drawn.length > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;
    for (final (count, color) in drawn) {
      final sweep = 2 * math.pi * count / total;
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.01), false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments.length != segments.length ||
      [for (var i = 0; i < segments.length; i++) old.segments[i] != segments[i]].any((d) => d);
}
