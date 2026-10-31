import 'insights.dart';

/// The one-line answers on Reports (owner_reports_page.dart). Pure, so the
/// wording is unit-tested in test/report_summary_test.dart.

const kReportMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String reportMonthName(DateTime m) => kReportMonthNames[m.month - 1];
String reportMonthShort(DateTime m) => kReportMonthNames[m.month - 1].substring(0, 3);

/// "12% more than September", "8% less than September", "Same as
/// September", or a plain note when last month had nothing to compare with.
String changeVsLastMonth(double current, double previous, DateTime previousMonth) {
  final name = reportMonthName(previousMonth);
  if (previous <= 0) {
    return current <= 0 ? 'Nothing in $name either' : 'Nothing in $name to compare with';
  }
  final pct = ((current - previous) / previous * 100).round();
  if (pct == 0) return 'Same as $name';
  return pct > 0 ? '$pct% more than $name' : '${-pct}% less than $name';
}

/// Whether [current] is up (1), down (-1) or level (0) on [previous] -
/// drives the arrow beside the change line.
int changeDirection(double current, double previous) {
  if (previous <= 0) return 0;
  final pct = ((current - previous) / previous * 100).round();
  return pct.sign;
}

/// Where this month's takings will land at the current daily rate, or null
/// when [month] isn't the current one or it's too early (before the 3rd)
/// for the rate to mean anything.
double? onPaceFor(double soFar, DateTime month, DateTime now) {
  if (month.year != now.year || month.month != now.month) return null;
  if (now.day < 3 || soFar <= 0) return null;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  return soFar / now.day * daysInMonth;
}

/// One service's month, from the monthlyStats `byService` / `serviceQty`
/// groups.
class ServiceMonth {
  final String name;
  final double takings;
  final int count;
  const ServiceMonth(this.name, this.takings, this.count);
}

/// The month's services, biggest earner first. [names] maps service id to
/// name; a service since removed from the menu shows as "Removed service".
List<ServiceMonth> topServices(RollupStats month, Map<String, String> names) {
  final takings = month.group('byService');
  final qty = month.group('serviceQty');
  final out = [
    for (final e in takings.entries)
      ServiceMonth(names[e.key] ?? 'Removed service', e.value, (qty[e.key] ?? 0).round()),
  ]..sort((a, b) => b.takings.compareTo(a.takings));
  return out;
}
