import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/insights.dart';
import 'package:mobile/data/report_summary.dart';

void main() {
  final sep = DateTime(2026, 9, 1);

  test('change against last month reads as words', () {
    expect(changeVsLastMonth(1120, 1000, sep), '12% more than September');
    expect(changeVsLastMonth(920, 1000, sep), '8% less than September');
    expect(changeVsLastMonth(1001, 1000, sep), 'Same as September');
    expect(changeVsLastMonth(500, 0, sep), 'Nothing in September to compare with');
    expect(changeVsLastMonth(0, 0, sep), 'Nothing in September either');
    expect(changeDirection(1120, 1000), 1);
    expect(changeDirection(920, 1000), -1);
    expect(changeDirection(500, 0), 0);
  });

  test('on pace only for the current month, from the 3rd on', () {
    final oct = DateTime(2026, 10, 1);
    expect(onPaceFor(10000, oct, DateTime(2026, 10, 10)), closeTo(31000, 0.01));
    expect(onPaceFor(10000, oct, DateTime(2026, 10, 2)), isNull);
    expect(onPaceFor(10000, sep, DateTime(2026, 10, 10)), isNull);
    expect(onPaceFor(0, oct, DateTime(2026, 10, 10)), isNull);
  });

  test('top services come from the month rollup, biggest first', () {
    final month = RollupStats.fromDoc({
      'byService': {'s1': 800, 's2': 2400, 'gone': 100},
      'serviceQty': {'s1': 4, 's2': 2, 'gone': 1},
    });
    final top = topServices(month, {'s1': 'Haircut', 's2': 'Hair colour'});
    expect([for (final s in top) s.name], ['Hair colour', 'Haircut', 'Removed service']);
    expect(top.first.count, 2);
    expect(top[1].takings, 800);
  });
}
