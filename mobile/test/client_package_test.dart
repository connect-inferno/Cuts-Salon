import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/client_package.dart';

final _now = DateTime(2026, 11, 6, 12);

ClientPackage _pkg(
  String id, {
  String client = 'c1',
  double paid = 5000,
  double worth = 6000,
  double? balance,
  DateTime? expires,
}) =>
    ClientPackage(
      id: id,
      customerId: client,
      paidAmount: paid,
      creditValue: worth,
      balance: balance ?? worth,
      paymentMethod: 'UPI',
      expiresAt: expires ?? DateTime(2027, 5, 6),
    );

void main() {
  group('plans', () {
    test('a sound plan has no problem', () {
      expect(const PackagePlan(pay: 5000, worth: 6000, months: 6).problem, isNull);
    });

    test('a plan worth less than it costs is refused', () {
      expect(const PackagePlan(pay: 5000, worth: 4000, months: 6).problem, isNotNull);
    });

    test('a plan needs a price and a validity', () {
      expect(const PackagePlan(pay: 0, worth: 6000, months: 6).problem, isNotNull);
      expect(const PackagePlan(pay: 5000, worth: 6000, months: 0).problem, isNotNull);
    });

    test('a plan survives being stored', () {
      final plan = PackagePlan.fromMap(const PackagePlan(pay: 10000, worth: 12500, months: 12).toMap());
      expect(plan.pay, 10000);
      expect(plan.worth, 12500);
      expect(plan.months, 12);
    });
  });

  group('which credit can be used', () {
    test('an expired package cannot be used', () {
      final expired = _pkg('a', expires: DateTime(2026, 11, 1));
      expect(expired.isUsableAt(_now), isFalse);
      expect(usableCredit([expired], 'c1', _now), 0);
    });

    test('a spent package cannot be used', () {
      expect(_pkg('a', balance: 0).isUsableAt(_now), isFalse);
    });

    test('a package is for one client only', () {
      expect(usableCredit([_pkg('a')], 'someone else', _now), 0);
      expect(usableCredit([_pkg('a')], null, _now), 0);
    });

    test('credit adds up across packages', () {
      expect(usableCredit([_pkg('a', balance: 1000), _pkg('b', balance: 2500)], 'c1', _now), 3500);
    });

    test('the package expiring soonest goes first', () {
      final late = _pkg('late', expires: DateTime(2027, 12, 1));
      final soon = _pkg('soon', expires: DateTime(2026, 12, 1));
      expect(usablePackages([late, soon], 'c1', _now).first.id, 'soon');
    });
  });

  group('drawing credit', () {
    test('a small bill comes out of one package', () {
      expect(drawFromPackages([_pkg('a')], 1200), {'a': 1200});
    });

    test('a big bill runs across packages in order', () {
      final draws = drawFromPackages([_pkg('a', balance: 1000), _pkg('b', balance: 5000)], 2500);
      expect(draws, {'a': 1000, 'b': 1500});
    });

    test('it never takes more than a package holds', () {
      final draws = drawFromPackages([_pkg('a', balance: 1000)], 2500);
      expect(draws, {'a': 1000});
    });

    test('nothing is drawn for nothing', () {
      expect(drawFromPackages([_pkg('a')], 0), isEmpty);
    });
  });

  group('the bonus', () {
    test('pay 5,000 for 6,000 makes a sixth of each rupee a bonus', () {
      expect(_pkg('a').bonusRate, closeTo(1 / 6, 0.0001));
    });

    test('spending the whole package gives the whole bonus', () {
      expect(packageBonusOf({'a': 6000}, [_pkg('a')]), 1000);
    });

    test('spending part gives its share', () {
      expect(packageBonusOf({'a': 600}, [_pkg('a')]), 100);
    });

    test('the bonus adds up across different plans', () {
      final big = _pkg('b', paid: 10000, worth: 12500);
      expect(packageBonusOf({'a': 600, 'b': 1250}, [_pkg('a'), big]), 350);
    });
  });

  group('expiry dates', () {
    test('adds whole months', () {
      expect(addMonths(DateTime(2026, 11, 6), 6), DateTime(2027, 5, 6));
    });

    test('crosses a year', () {
      expect(addMonths(DateTime(2026, 11, 6), 18), DateTime(2028, 5, 6));
    });

    test('lands on the last day of a shorter month', () {
      expect(addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
    });
  });
}
