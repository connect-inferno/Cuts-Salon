import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/client_package.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/data/service_menu.dart';

SalonService _svc(String id, String name, {String? category, String? audience}) => SalonService(
      id: id,
      name: name,
      price: 100,
      categoryId: category ?? '',
      categoryName: category,
      audience: audience,
    );

void main() {
  group('who a service is for', () {
    test('a service with no audience shows for everyone', () {
      expect(audiencesOverlap(null, kAudienceGents), isTrue);
      expect(audiencesOverlap(kAudienceLadies, null), isTrue);
    });

    test('Gents and Ladies services do not clash', () {
      expect(audiencesOverlap(kAudienceGents, kAudienceLadies), isFalse);
      expect(audiencesOverlap(kAudienceGents, kAudienceGents), isTrue);
    });

    test('the client\'s gender picks the tab, and blank leaves it alone', () {
      expect(audienceForGender('MALE'), kAudienceGents);
      expect(audienceForGender('f'), kAudienceLadies);
      expect(audienceForGender(null), isNull);
    });

    test('stored codes are never shown raw', () {
      expect(serviceAudienceLabel(kAudienceGents), 'Gents');
      expect(serviceAudienceLabel(kAudienceLadies), 'Ladies');
      expect(serviceAudienceLabel(null), 'Gents and Ladies');
    });
  });

  group('category choices', () {
    test('each side only offers its own part of the menu', () {
      final gents = serviceCategoryChoices(kAudienceGents, const []);
      final ladies = serviceCategoryChoices(kAudienceLadies, const []);
      expect(gents, contains('Shaving'));
      expect(gents, isNot(contains('Threading')));
      expect(ladies, contains('Threading'));
      expect(ladies, isNot(contains('Shaving')));
      expect(gents, contains('Facial'));
      expect(ladies, contains('Facial'));
    });

    test('both shows the whole menu', () {
      expect(serviceCategoryChoices(null, const []).length, kServiceMenu.length);
    });

    test('a salon\'s own categories come after the menu, without repeats', () {
      final choices = serviceCategoryChoices(kAudienceGents, const ['Nail Art', 'clean up', ' ']);
      expect(choices.last, 'Nail Art');
      expect(choices.where((c) => c.toLowerCase() == 'clean up').length, 1);
      expect(choices, isNot(contains(' ')));
    });
  });

  group('grouping', () {
    test('categories follow the menu, then the salon\'s own, then Other', () {
      final groups = groupServices([
        _svc('1', 'No home'),
        _svc('2', 'Art', category: 'Nail Art'),
        _svc('3', 'Fruit', category: 'Facial'),
        _svc('4', 'Mens', category: 'Cut with Wash'),
      ]);
      expect(groups.map((g) => g.name), ['Cut with Wash', 'Facial', 'Nail Art', kUncategorised]);
    });

    test('services inside a category go by name', () {
      final groups = groupServices([
        _svc('1', 'Rich Feel', category: 'Clean Up'),
        _svc('2', 'lotus', category: 'Clean Up'),
      ]);
      expect(groups.single.services.map((s) => s.name), ['lotus', 'Rich Feel']);
    });

    test('a category keeps all of its services', () {
      final groups = groupServices([
        _svc('1', 'Regular', category: 'Clean Up'),
        _svc('2', 'Lotus', category: 'Clean Up'),
      ]);
      expect(groups.single.services.length, 2);
    });
  });

  group('variable prices', () {
    SalonService varying({double price = 0, List<double> options = const []}) => SalonService(
          id: 'v',
          name: 'O3+',
          price: price,
          categoryId: 'c',
          priceVaries: true,
          priceOptions: options,
        );

    test('a fixed price shows as it is', () {
      expect(servicePriceLabel(_svc('1', 'Cut', category: 'Cut with Wash')), '₹100');
    });

    test('tiers show as a range', () {
      expect(servicePriceLabel(varying(price: 2900, options: const [2900, 3400, 3900])), '₹2,900 - ₹3,900');
    });

    test('no price at all says it depends', () {
      expect(servicePriceLabel(varying()), 'On consultation');
    });

    test('typed prices are sorted and cleaned up', () {
      expect(parsePriceOptions('3400, 2900 / 3900, 2900, abc, 0'), [2900, 3400, 3900]);
      expect(parsePriceOptions('  '), isEmpty);
    });
  });

  group('the Cuts menu file', () {
    final menu = SalonMenu.fromMap(jsonDecode(File('assets/menus/cuts.json').readAsStringSync()) as Map<String, dynamic>);

    test('every category is one the menu knows', () {
      final known = {for (final c in kServiceMenu) c.name};
      expect(menu.services.map((s) => s.category).toSet().difference(known), isEmpty);
    });

    test('every category is offered on the side its services are for', () {
      for (final s in menu.services) {
        expect(serviceCategoryChoices(s.audience, const []), contains(s.category), reason: s.name);
      }
    });

    test('no service appears twice for the same clients', () {
      final seen = <String>{};
      for (final s in menu.services) {
        for (final side in s.audience == null ? [kAudienceGents, kAudienceLadies] : [s.audience!]) {
          expect(seen.add('$side|${s.category}|${s.name}'.toLowerCase()), isTrue, reason: s.name);
        }
      }
    });

    test('a fixed price is never zero', () {
      for (final s in menu.services.where((s) => !s.priceVaries)) {
        expect(s.price, greaterThan(0), reason: s.name);
      }
    });

    test('the price tiers and the three packages came across', () {
      final hydra = menu.services.firstWhere((s) => s.category == 'Hydra Facial' && s.name == 'O3+');
      expect(hydra.priceOptions, [2900, 3400, 3900]);
      expect(menu.packagePlans.map((p) => p.pay), [5000, 10000, 20000]);
      expect(menu.packagePlans.every((PackagePlan p) => p.problem == null), isTrue);
    });
  });

  group('loading a menu', () {
    const entry = MenuEntry(category: 'Clean Up', name: 'Regular', price: 600);

    test('a new service is added', () {
      expect(menuEntriesToAdd([entry], const []), [entry]);
    });

    test('loading again adds nothing', () {
      expect(menuEntriesToAdd([entry], [_svc('1', 'regular', category: 'clean up')]), isEmpty);
    });

    test('the same name in another category still goes in', () {
      expect(menuEntriesToAdd([entry], [_svc('1', 'Regular', category: 'Manicure')]), [entry]);
    });

    test('a Ladies service is not blocked by a Gents one', () {
      const ladies = MenuEntry(category: 'Hair Spa', name: 'Frizz Hair', price: 1000, audience: kAudienceLadies);
      final gents = _svc('1', 'Frizz Hair', category: 'Hair Spa', audience: kAudienceGents);
      expect(menuEntriesToAdd([ladies], [gents]), [ladies]);
    });
  });

  group('popular services', () {
    Bill bill(List<String> serviceIds) => Bill(
          id: 'b',
          invoiceNumber: 'INV',
          customerId: 'c',
          branchId: 'b1',
          subTotal: 0,
          discountAmount: 0,
          taxAmount: 0,
          finalAmount: 0,
          paymentMethod: 'UPI',
          status: 'COMPLETED',
          items: [
            for (final id in serviceIds)
              BillItem(
                id: 'i$id',
                type: 'SERVICE',
                serviceId: id,
                quantity: 1,
                unitPrice: 0,
                discountAmount: 0,
                employeeId: 'e',
                calculatedCommission: 0,
              ),
          ],
        );
    final cut = _svc('cut', 'Cut', category: 'Cut with Wash');
    final trim = _svc('trim', 'Trim', category: 'Shaving');
    final spa = _svc('spa', 'Spa', category: 'Hair Spa');

    test('the most billed comes first', () {
      final top = popularServices([bill(['trim', 'cut']), bill(['cut'])], [trim, cut, spa]);
      expect(top.map((s) => s.id), ['cut', 'trim']);
    });

    test('a service never billed is left out', () {
      expect(popularServices([bill(['cut'])], [cut, spa]).map((s) => s.id), ['cut']);
    });

    test('a removed service is left out', () {
      expect(popularServices([bill(['gone', 'cut'])], [cut]).map((s) => s.id), ['cut']);
    });

    test('the list stops at the limit', () {
      expect(popularServices([bill(['cut', 'trim', 'spa'])], [cut, trim, spa], limit: 2).length, 2);
    });

    test('a salon with no bills has none', () {
      expect(popularServices(const [], [cut]), isEmpty);
    });
  });

  group('bill line names', () {
    final regularCleanUp = _svc('1', 'Regular', category: 'Clean Up');
    final regularManicure = _svc('2', 'Regular', category: 'Manicure');
    final haircut = _svc('3', 'Haircut', category: 'Cut with Wash');
    final all = [regularCleanUp, regularManicure, haircut];

    test('a name used in two categories says which one', () {
      expect(billLineName(regularCleanUp, all), 'Regular (Clean Up)');
      expect(billLineName(regularManicure, all), 'Regular (Manicure)');
    });

    test('a name used once stays as it is', () {
      expect(billLineName(haircut, all), 'Haircut');
    });

    test('Gents and Ladies versions in one category need no suffix', () {
      final gents = _svc('4', 'Frizz hair', category: 'Hair Spa', audience: kAudienceGents);
      final ladies = _svc('5', 'Frizz hair', category: 'Hair Spa', audience: kAudienceLadies);
      expect(billLineName(gents, [gents, ladies]), 'Frizz hair');
    });

    test('a service with no category stays as it is', () {
      final plain = _svc('6', 'Regular');
      expect(billLineName(plain, [plain, regularCleanUp]), 'Regular');
    });
  });
}
