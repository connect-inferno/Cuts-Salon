import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/firestore_app_data.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'app_data_provider.dart';
import 'insights.dart';

/// The rollup docs behind Reports' charts, loaded when Reports opens (owner
/// only - the rules keep both collections owner-only) rather than at
/// sign-in: ~13 month docs, ~30 day docs and one flag, about 45 reads.
class InsightsData {
  /// 'YYYY-MM' -> that month's totals, for the last 12 months.
  final Map<String, RollupStats> months;

  /// 'YYYY-MM-DD' -> that day's totals, for the last 30 days.
  final Map<String, RollupStats> days;

  /// When live rollups started (the earliest `liveSince`), or null if no
  /// bill has been raised since this version shipped.
  final DateTime? liveSince;
  final bool backfillDone;

  const InsightsData({
    required this.months,
    required this.days,
    required this.liveSince,
    required this.backfillDone,
  });

  RollupStats month(DateTime m) => months[monthKey(m)] ?? RollupStats.empty;

  RollupStats window(List<DateTime> ms) => RollupStats.sum(ms.map(month));

  /// Whether months before the live rollups could still be filled in from
  /// the bills.
  bool needsBackfill(DateTime? oldestKnownBill) {
    if (backfillDone || oldestKnownBill == null) return false;
    final since = liveSince;
    return since == null || oldestKnownBill.isBefore(since);
  }
}

class InsightsNotifier extends AutoDisposeAsyncNotifier<InsightsData> {
  SalonFirestore? _fs;

  @override
  Future<InsightsData> build() async {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated || !auth.isOwner) {
      return const InsightsData(months: {}, days: {}, liveSince: null, backfillDone: true);
    }
    final app = SalonAuth.currentApp(auth.salonId!);
    if (app == null) throw Exception('Not signed in');
    final fs = _fs = SalonFirestore(app);
    return _load(fs);
  }

  Future<InsightsData> _load(SalonFirestore fs) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 11, 1);
    final dayFrom = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final results = await Future.wait([
      fs.listMonthlyStats(from),
      fs.listDailyStatsSince(dayFrom),
      fs.monthlyBackfillDone(),
    ]);
    final monthDocs = results[0] as Map<String, Map<String, dynamic>>;
    final dayDocs = results[1] as Map<String, Map<String, dynamic>>;

    DateTime? liveSince;
    for (final d in monthDocs.values) {
      final t = d['liveSince'];
      if (t is Timestamp && (liveSince == null || t.toDate().isBefore(liveSince))) liveSince = t.toDate();
    }
    return InsightsData(
      months: {for (final e in monthDocs.entries) e.key: RollupStats.fromDoc(e.value)},
      days: {for (final e in dayDocs.entries) e.key: RollupStats.fromDoc(e.value)},
      liveSince: liveSince,
      backfillDone: results[2] as bool,
    );
  }

  /// Fills in the months before live rollups started, from the bills
  /// themselves: one read per bill and item in the last 12 months, once.
  /// Bills raised from here on already roll themselves up.
  Future<void> backfill() async {
    final fs = _fs;
    final current = state.value;
    final appData = ref.read(appDataProvider).value;
    if (fs == null || current == null || appData == null) throw Exception('Not ready yet - try again in a moment');

    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month - 11, 1);
    final cutoff = current.liveSince ?? now;
    final raw = await fs.listBillsWithItemsBetween(windowStart, cutoff);
    final bills = [for (final (b, items) in raw) billFromFS(b, items: items)];
    final byMonth = backfillMonthlyRollups(
      bills: bills,
      customers: [...appData.customers, ...appData.archivedCustomers],
      services: appData.services,
      inventory: appData.inventory,
      cutoff: cutoff,
      windowStart: windowStart,
    );
    await fs.saveMonthlyBackfill(byMonth, cutoff);
    state = AsyncData(await _load(fs));
  }

  Future<void> refresh() async {
    final fs = _fs;
    if (fs == null) return;
    state = await AsyncValue.guard(() => _load(fs));
  }
}

final insightsProvider =
    AsyncNotifierProvider.autoDispose<InsightsNotifier, InsightsData>(InsightsNotifier.new);
