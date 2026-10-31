// The WhatsApp page (Menu > WhatsApp) and one task's page: they lay out at
// phone and laptop width, show each message's rule and count, and save the
// owner's choices through updateWhatsAppTasks - plus the pure helpers
// behind them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
import 'package:mobile/data/insights.dart';
import 'package:mobile/data/insights_provider.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/data/whatsapp_tasks.dart';
import 'package:mobile/features/owner/widgets/owner_whatsapp_page.dart';

final _now = DateTime.now();

SalonSettings _settings({bool ready = true, bool enabled = true, int days = 21, int before = 0, bool billOn = true}) =>
    SalonSettings(
      salonName: 'Cuts Salon',
      gstRate: 0,
      lateAttendancePenalty: 0,
      whatsappReady: ready,
      whatsappEnabled: enabled,
      whatsappReminderDays: days,
      whatsappBirthdayDaysBefore: before,
      whatsappBillOn: billOn,
    );

Customer _c(String id, {bool wa = true, String? birthday}) => Customer(
      id: id,
      name: 'Client $id',
      phone: '98765$id',
      isVip: false,
      branchId: 'b',
      whatsappOptIn: wa,
      birthday: birthday,
    );

AppData _data(SalonSettings s) => AppData(
      branches: const [],
      employees: const [],
      customers: [_c('1', birthday: '03-14'), _c('2'), _c('3', wa: false)],
      categories: const [],
      services: [
        SalonService(id: 's1', name: 'Haircut', price: 300, categoryId: 'c', reminderDays: 30),
        SalonService(id: 's2', name: 'Hair colour', price: 1500, categoryId: 'c', reminderDays: 45),
        SalonService(id: 's3', name: 'Head massage', price: 200, categoryId: 'c'),
      ],
      inventory: const [],
      bills: const [],
      salesTargets: const [],
      commissions: const [],
      attendance: const [],
      dashboard: null,
      settings: s,
    );

class _StubAppData extends AppDataNotifier {
  _StubAppData(this._d, this.saved);
  final AppData _d;
  final List<Map<String, dynamic>> saved;

  @override
  Future<AppData> build() async => _d;

  @override
  Future<void> updateWhatsAppTasks(Map<String, dynamic> changes) async => saved.add(changes);
}

class _StubInsights extends InsightsNotifier {
  @override
  Future<InsightsData> build() async {
    final months = <String, RollupStats>{};
    for (var i = 0; i < 6; i++) {
      final m = DateTime(_now.year, _now.month - i, 1);
      months[monthKey(m)] = RollupStats.fromDoc({
        'reminderReturns': i == 0 ? 7 : 3,
        'reminderReturnSales': 4200,
        'wa': {'receipts': 40 + i, 'birthdays': i, 'reminders': 18 - i},
      });
    }
    return InsightsData(months: months, days: const {}, liveSince: _now, backfillDone: true);
  }
}

final _log = [
  WhatsAppLogEntry(id: 'a', task: WhatsAppTask.reminder, customerName: 'Priya Sharma', status: 'sent', at: _now),
  WhatsAppLogEntry(
    id: 'b',
    task: WhatsAppTask.reminder,
    customerName: 'A client with a really quite long name indeed',
    status: 'failed',
    at: _now.subtract(const Duration(days: 1)),
    error: 'WhatsApp API 400: Template name does not exist (code 132001)',
  ),
];

Future<List<Map<String, dynamic>>> _pump(WidgetTester tester, Widget page, {double width = 375, SalonSettings? settings}) async {
  tester.view.physicalSize = Size(width, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saved = <Map<String, dynamic>>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDataProvider.overrideWith(() => _StubAppData(_data(settings ?? _settings()), saved)),
      insightsProvider.overrideWith(_StubInsights.new),
      whatsAppLogProvider.overrideWith((ref, task) async => _log),
    ],
    child: MaterialApp(home: Scaffold(body: page)),
  ));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  group('helpers', () {
    test('rule says when each message goes', () {
      expect(WhatsAppTask.reminder.rule(_settings(days: 30)), '30 days after the last visit, 10:00 AM');
      expect(WhatsAppTask.birthday.rule(_settings(before: 1)), 'The day before the birthday, 10:00 AM');
      expect(WhatsAppTask.birthday.rule(_settings()), 'On the birthday, 10:00 AM');
      expect(WhatsAppTask.bill.isOn(_settings(billOn: false)), isFalse);
    });

    test('monthlySent reads the wa counter per month, oldest first', () {
      final s = monthlySent(
        WhatsAppTask.birthday,
        (m, k) => k == 'wa.birthdays' ? m.month.toDouble() : 0,
        now: DateTime(2026, 2, 10),
      );
      expect(s.labels, ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb']);
      expect(s.values, [9, 10, 11, 12, 1, 2]);
    });

    test('log times read like a person would say them', () {
      final now = DateTime(2026, 10, 31, 15);
      expect(whatsAppLogTime(DateTime(2026, 10, 31, 10, 1), now), 'Today, 10:01');
      expect(whatsAppLogTime(DateTime(2026, 10, 30, 9, 5), now), 'Yesterday, 09:05');
      expect(whatsAppLogTime(DateTime(2026, 10, 2, 18, 30), now), '2 Oct, 18:30');
      expect(whatsAppLogTime(DateTime(2025, 12, 2, 18, 30), now), '2 Dec 2025, 18:30');
    });

    test('the earliest service gap on a bill wins, none means the default', () {
      SalonService s(int? d) => SalonService(id: '$d', name: 'S', price: 1, categoryId: 'c', reminderDays: d);
      expect(earliestServiceReminderDays([s(45), s(30), s(null)]), 30);
      expect(earliestServiceReminderDays([s(null)]), isNull);
      expect(earliestServiceReminderDays(const []), isNull);
    });

    test('reminder due date counts calendar days, across month and year ends', () {
      expect(reminderDueDate(DateTime(2026, 10, 31, 18, 40), 30), '2026-11-30');
      expect(reminderDueDate(DateTime(2026, 12, 20), 21), '2027-01-10');
      expect(reminderDueDate(DateTime(2026, 2, 1), 28), '2026-03-01');
    });

    test('common Meta errors become plain sentences', () {
      expect(whatsAppErrorText('WhatsApp API 400: x (code 132001)'), contains('template is not approved'));
      expect(whatsAppErrorText('WhatsApp API 401: Error validating access token (code 190)'), contains('expired'));
      expect(whatsAppErrorText('WhatsApp API 400: (#131030) Recipient phone number not in allowed list (code 131030)'),
          contains('allowed list of your WhatsApp test number'));
      expect(whatsAppErrorText(null), 'Not sent - no reason given.');
      expect(whatsAppErrorText('Something new'), 'Something new');
    });
  });

  for (final width in [360.0, 1024.0]) {
    testWidgets('WhatsApp page lays out at ${width.round()}px', (tester) async {
      await _pump(tester, const OwnerWhatsAppPage(), width: width);
      expect(tester.takeException(), isNull);
      expect(find.text('Automatic messages'), findsOneWidget);
      for (final t in WhatsAppTask.values) {
        expect(find.text(t.title), findsOneWidget);
      }
      expect(find.text('21 days after the last visit, 10:00 AM'), findsOneWidget);
      expect(find.text('18 sent this month · 7 came back'), findsOneWidget);
      expect(find.textContaining('2 of 3 clients'), findsOneWidget);
      // The failed reminder in the log shows as a warning with a way to it.
      expect(find.textContaining("didn't go out this week"), findsOneWidget);
    });

    testWidgets('reminder page lays out at ${width.round()}px', (tester) async {
      await _pump(tester, const OwnerWhatsAppTaskPage(task: WhatsAppTask.reminder), width: width);
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(list, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('picking a reminder gap saves it', (tester) async {
    final saved = await _pump(tester, const OwnerWhatsAppTaskPage(task: WhatsAppTask.reminder));
    expect(find.text('Send after (salon default)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('whatsappChoice_30')));
    await tester.pumpAndSettle();
    expect(saved, [
      {'whatsappReminderDays': 30},
    ]);
  });

  testWidgets('the reminder page lists services with their own gap, earliest first', (tester) async {
    await _pump(tester, const OwnerWhatsAppTaskPage(task: WhatsAppTask.reminder), width: 1024);
    expect(find.text('Services with their own gap'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('30 days'), findsWidgets);
    expect(find.text('Hair colour'), findsOneWidget);
    expect(find.text('45 days'), findsWidgets);
    expect(find.text('Head massage'), findsNothing);
    final haircut = tester.getTopLeft(find.text('Haircut')).dy;
    expect(haircut, lessThan(tester.getTopLeft(find.text('Hair colour')).dy));
  });

  testWidgets('switching a message off saves its own switch', (tester) async {
    final saved = await _pump(tester, const OwnerWhatsAppPage());
    await tester.tap(find.byKey(const Key('whatsappTaskSwitch_birthday')));
    await tester.pumpAndSettle();
    expect(saved, [
      {'whatsappBirthdayOn': false},
    ]);
  });

  testWidgets('a failed send shows why, in plain words', (tester) async {
    await _pump(tester, const OwnerWhatsAppTaskPage(task: WhatsAppTask.reminder), width: 1024);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(find.text('Failed'), findsOneWidget);
    expect(find.textContaining('template is not approved'), findsWidgets);
  });

  testWidgets('a salon without WhatsApp set up gets the contact card', (tester) async {
    await _pump(tester, const OwnerWhatsAppPage(), settings: _settings(ready: false));
    expect(find.text('WhatsApp us'), findsOneWidget);
    expect(find.text('Automatic messages'), findsNothing);
  });
}
