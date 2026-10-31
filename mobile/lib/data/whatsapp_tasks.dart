import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_provider.dart';
import '../firebase/salon_auth.dart';
import '../firebase/salon_firestore.dart';
import 'models.dart';

/// The three automatic WhatsApp messages the Cloud Functions send
/// (functions/index.js), as the owner's WhatsApp page shows them.
enum WhatsAppTask {
  bill(
    title: 'Bill receipt',
    logKind: 'bill',
    counter: 'receipts',
    settingKey: 'whatsappBillOn',
  ),
  birthday(
    title: 'Birthday wish',
    logKind: 'birthday',
    counter: 'birthdays',
    settingKey: 'whatsappBirthdayOn',
  ),
  reminder(
    title: 'Come-back reminder',
    logKind: 'reminder',
    counter: 'reminders',
    settingKey: 'whatsappReminderOn',
  );

  const WhatsAppTask({
    required this.title,
    required this.logKind,
    required this.counter,
    required this.settingKey,
  });

  final String title;

  /// `kind` on its whatsappLog entries.
  final String logKind;

  /// Its counter under monthlyStats.wa (whatsapp_core.sendCounterFor).
  final String counter;

  /// Its on/off field on settings/main.
  final String settingKey;

  bool isOn(SalonSettings s) => switch (this) {
        WhatsAppTask.bill => s.whatsappBillOn,
        WhatsAppTask.birthday => s.whatsappBirthdayOn,
        WhatsAppTask.reminder => s.whatsappReminderOn,
      };

  /// When it goes, in words - the line under the task's name.
  String rule(SalonSettings s) => switch (this) {
        WhatsAppTask.bill => 'Right after each bill is saved',
        WhatsAppTask.birthday => s.whatsappBirthdayDaysBefore == 1
            ? 'The day before the birthday, 10:00 AM'
            : 'On the birthday, 10:00 AM',
        WhatsAppTask.reminder => '${s.whatsappReminderDays} days after the last visit, 10:00 AM',
      };

  static WhatsAppTask? fromLogKind(String kind) {
    for (final t in values) {
      if (t.logKind == kind) return t;
    }
    return null;
  }
}

/// The come-back gaps the owner can pick, in days. Inside the 7-120 the
/// functions accept (whatsapp_core.taskSettings).
const List<int> kReminderDayChoices = [7, 14, 21, 30, 45, 60, 90];

/// One message the functions sent or tried to send (whatsappLog/{key}).
class WhatsAppLogEntry {
  final String id;
  final WhatsAppTask? task;
  final String customerName;
  /// 'sending' | 'sent' | 'failed'
  final String status;
  final DateTime? at;
  final String? error;

  const WhatsAppLogEntry({
    required this.id,
    required this.task,
    required this.customerName,
    required this.status,
    required this.at,
    this.error,
  });

  bool get failed => status == 'failed';
  bool get sent => status == 'sent';

  factory WhatsAppLogEntry.fromMap(String id, Map<String, dynamic> d) {
    final sentAt = d['sentAt'];
    final createdAt = d['createdAt'];
    final when = sentAt is Timestamp ? sentAt : (createdAt is Timestamp ? createdAt : null);
    return WhatsAppLogEntry(
      id: id,
      task: WhatsAppTask.fromLogKind(d['kind'] as String? ?? ''),
      customerName: (d['customerName'] as String?)?.trim().isNotEmpty == true ? d['customerName'] as String : 'A client',
      status: d['status'] as String? ?? 'sending',
      at: when?.toDate(),
      error: d['error'] as String?,
    );
  }
}

/// Plain-words reason for a failed send. Meta's raw errors ("WhatsApp API
/// 400: ... (code 132001)") mean nothing to a salon owner; the common ones
/// get a sentence, the rest show as they came.
String whatsAppErrorText(String? raw) {
  final e = raw ?? '';
  if (e.contains('132001') || e.toLowerCase().contains('template')) {
    return 'The message template is not approved yet. Ask the Stylux team to check it.';
  }
  if (e.contains('131030')) {
    return "This phone isn't on the allowed list of your WhatsApp test number. A live business number doesn't have this limit.";
  }
  if (e.contains('131026') || e.contains('131047')) {
    return "This number can't receive it (not on WhatsApp, or hasn't messaged you in 24 hours).";
  }
  if (e.contains(' 401') || e.contains('190') || e.toLowerCase().contains('token')) {
    return 'The WhatsApp connection has expired. Ask the Stylux team to renew it.';
  }
  return e.isEmpty ? 'Not sent - no reason given.' : e;
}

/// The latest messages, newest first: all of them, or one task's.
/// Owner-only (whatsappLog rules); one read per message shown.
final whatsAppLogProvider =
    FutureProvider.autoDispose.family<List<WhatsAppLogEntry>, WhatsAppTask?>((ref, task) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || !auth.isOwner) return const [];
  final app = SalonAuth.currentApp(auth.salonId!);
  if (app == null) throw Exception('Not signed in');
  final raw = await SalonFirestore(app).listWhatsAppLog(kind: task?.logKind, limit: task == null ? 20 : 30);
  return [for (final (id, d) in raw) WhatsAppLogEntry.fromMap(id, d)];
});

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// One task's sends for the last [months] months, oldest first, from the
/// monthlyStats `wa` counters the functions add to on every successful send.
/// [monthStats] is InsightsData.month.
({List<String> labels, List<double> values}) monthlySent(
  WhatsAppTask task,
  double Function(DateTime month, String key) monthStats, {
  required DateTime now,
  int months = 6,
}) {
  final labels = <String>[];
  final values = <double>[];
  for (var i = months - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    labels.add(_monthNames[m.month - 1]);
    values.add(monthStats(m, 'wa.${task.counter}'));
  }
  return (labels: labels, values: values);
}

/// "Today, 10:01", "Yesterday, 18:20", "28 Oct, 10:01" (IST is the
/// device's own time on every salon phone).
String whatsAppLogTime(DateTime at, DateTime now) {
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  final date = diff == 0
      ? 'Today'
      : diff == 1
          ? 'Yesterday'
          : '${at.day} ${_monthNames[at.month - 1]}${at.year == now.year ? '' : ' ${at.year}'}';
  return '$date, $hh:$mm';
}

/// The earliest of these services' own come-back gaps, or null when none
/// has one (the salon's general gap applies). A haircut at 30 days and a
/// colour at 45 on one bill means the reminder goes at 30.
int? earliestServiceReminderDays(Iterable<SalonService> services) {
  int? best;
  for (final s in services) {
    final d = s.reminderDays;
    if (d != null && (best == null || d < best)) best = d;
  }
  return best;
}

/// "YYYY-MM-DD", [days] calendar days after [visit] - the date the daily
/// WhatsApp run (10:00 IST) sends the come-back reminder on.
String reminderDueDate(DateTime visit, int days) {
  final d = DateTime(visit.year, visit.month, visit.day + days);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
