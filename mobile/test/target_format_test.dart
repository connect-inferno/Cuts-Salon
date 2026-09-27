// A SERVICE_VOLUME target is a rupee quota; PRODUCT_SALES_COUNT is a count of
// units. The employee dashboard prints targets in two places now - the home
// screen card and the Target tab - and the tab's own comment records that a
// revenue target once rendered as a bare "50000" with no currency anywhere on
// screen. These pin the shared rule so the two cannot drift apart again.

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/employee/employee_dashboard.dart';

void main() {
  group('targetIsCurrency', () {
    test('service volume is money', () {
      expect(targetIsCurrency('SERVICE_VOLUME'), isTrue);
    });

    test('product sales count is not money', () {
      expect(targetIsCurrency('PRODUCT_SALES_COUNT'), isFalse);
    });

    test('an unknown type is treated as money', () {
      // Defaulting to a currency symbol is the safer wrong answer: a stray
      // rupee sign on a unit count reads as odd, a missing one on revenue
      // reads as a plausible number and misleads.
      expect(targetIsCurrency('SOMETHING_NEW'), isTrue);
    });
  });

  group('formatTargetValue', () {
    test('revenue carries a rupee symbol', () {
      expect(formatTargetValue('SERVICE_VOLUME', 50000), '₹50000');
    });

    test('a unit count does not', () {
      expect(formatTargetValue('PRODUCT_SALES_COUNT', 25), '25');
    });

    test('fractions are rounded away in both forms', () {
      expect(formatTargetValue('SERVICE_VOLUME', 4999.6), '₹5000');
      expect(formatTargetValue('PRODUCT_SALES_COUNT', 12.4), '12');
    });

    test('zero still renders', () {
      expect(formatTargetValue('SERVICE_VOLUME', 0), '₹0');
    });
  });

  group('targetTypeLabel', () {
    test('names each type in the salon\'s words, not the enum\'s', () {
      expect(targetTypeLabel('SERVICE_VOLUME'), 'Service revenue');
      expect(targetTypeLabel('PRODUCT_SALES_COUNT'), 'Product sales');
    });
  });

  group('SalesTarget.progressFraction', () {
    SalesTarget target(double progress, double goal) => SalesTarget(
          id: 't1',
          employeeId: 'e1',
          type: 'SERVICE_VOLUME',
          targetValue: goal,
          progressValue: progress,
          status: 'ACTIVE',
        );

    test('is the plain ratio partway through', () {
      expect(target(25000, 50000).progressFraction, 0.5);
    });

    test('clamps at 1 so an overshoot cannot overflow the bar', () {
      // The card feeds this straight to LinearProgressIndicator, which
      // asserts on values above 1.
      expect(target(75000, 50000).progressFraction, 1);
    });

    test('a zero goal does not divide by zero', () {
      expect(target(1000, 0).progressFraction, 0);
    });
  });
}
