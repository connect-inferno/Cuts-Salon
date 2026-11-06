// New Bill and its pick screen: a short bill with an Add services button,
// categories down the side, Gents / Ladies, search, prices settled on the
// bill, package credit, and the branch switch in the header. Pumped on a stub
// snapshot, so no Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
import 'package:mobile/data/client_package.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/data/service_menu.dart';
import 'package:mobile/features/owner/widgets/owner_billing_inventory_expenses_tab.dart';

SalonService _svc(String id, String name, String category, {String? audience, double price = 300}) => SalonService(
      id: id,
      name: name,
      price: price,
      categoryId: 'c-$category',
      categoryName: category,
      audience: audience,
    );

Branch _branch(String id, String name) => Branch(
      id: id,
      name: name,
      active: true,
      employeeCount: 1,
      customerCount: 1,
      monthlyRevenue: 0,
    );

AppData _data({
  List<Branch>? branches,
  List<SalonService>? services,
  List<ClientPackage> packages = const [],
  List<InventoryItem> inventory = const [],
  List<Bill> bills = const [],
}) =>
    AppData(
      branches: branches ?? [_branch('b1', 'Main Branch'), _branch('b2', 'Camp')],
      employees: [
        EmployeeProfile(
          id: 'e1',
          userId: 'e1',
          email: 'e1@x.test',
          name: 'Ravi',
          phone: '9876500002',
          roleTitle: 'Stylist',
          active: true,
          baseSalary: 0,
          serviceCommissionPct: 0,
          productCommissionPct: 0,
          branchId: 'b1',
        ),
      ],
      customers: [Customer(id: 'c1', name: 'Priya', phone: '9876500001', isVip: false, branchId: 'b1')],
      clientPackages: packages,
      categories: const [],
      services: services ??
          [
            _svc('1', 'Mens Cut', 'Cut with Wash', audience: kAudienceGents),
            _svc('2', 'Eyebrow', 'Threading', audience: kAudienceLadies),
            _svc('3', 'Fruit Facial', 'Facial'),
          ],
      inventory: inventory,
      bills: bills,
      salesTargets: const [],
      commissions: const [],
      attendance: const [],
      dashboard: null,
      settings: null,
    );

class _Stub extends AppDataNotifier {
  _Stub(this._data);
  final AppData _data;

  @override
  Future<AppData> build() async => _data;
}

Future<void> _pump(WidgetTester tester, AppData data, {Size size = const Size(390, 844), String? client}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDataProvider.overrideWith(() => _Stub(data))],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(body: OwnerBillingTab(preselectedCustomerId: client)),
            ),
            // pushAppRoute's stacked page.
            GoRoute(path: '/page', builder: (_, state) => state.extra as Widget),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Add services'));
  await tester.pumpAndSettle();
}

Future<void> _done(WidgetTester tester) async {
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

void main() {
  group('the new bill', () {
    testWidgets('starts as a client and an Add services button, with no menu', (tester) async {
      await _pump(tester, _data());
      expect(find.text('Add services'), findsOneWidget);
      expect(find.text('Mens Cut'), findsNothing);
      expect(find.text('Cut with Wash'), findsNothing);
      expect(find.text('Payment Method'), findsNothing);
    });

    testWidgets('picked services show on the bill with the payment choices', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      await _done(tester);
      expect(find.text('Mens Cut'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
    });

    testWidgets('a line can be taken off the bill', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      await _done(tester);
      await tester.tap(find.byTooltip('Remove Mens Cut'));
      await tester.pumpAndSettle();
      expect(find.text('Mens Cut'), findsNothing);
      expect(find.text('Payment Method'), findsNothing);
    });

    testWidgets('leaving by the back arrow keeps what was picked', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Mens Cut'), findsOneWidget);
    });

    testWidgets('a discount can be set to an exact percent', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      await _done(tester);
      await tester.ensureVisible(find.text('10%'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10%'));
      await tester.pumpAndSettle();
      expect(find.textContaining('10% (₹30 off)'), findsOneWidget);
      await tester.tap(find.byTooltip('More discount'));
      await tester.pumpAndSettle();
      expect(find.text('11%'), findsOneWidget);
    });
  });

  group('the totals', () {
    Future<void> billWithCut(WidgetTester tester) async {
      await _pump(tester, _data(), size: const Size(390, 1400), client: 'c1');
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      await _done(tester);
    }

    testWidgets('come last, after payment and discount', (tester) async {
      await billWithCut(tester);
      expect(
        tester.getTopLeft(find.text('Total Amount')).dy,
        greaterThan(tester.getTopLeft(find.text('Discount')).dy),
      );
    });

    testWidgets('an ordinary bill has nothing to split', (tester) async {
      await billWithCut(tester);
      expect(find.text('Paying now'), findsNothing);
      expect(find.text('Still owed'), findsNothing);
    });

    testWidgets('pay later with nothing typed owes the whole bill', (tester) async {
      await billWithCut(tester);
      await tester.tap(find.text('Pay later'));
      await tester.pumpAndSettle();
      expect(find.text('Paying now'), findsOneWidget);
      expect(find.text('Still owed'), findsOneWidget);
      expect(find.text('Paying now, ₹300 owed'), findsOneWidget);
    });

    testWidgets('part payment splits the total, and the bottom bar follows', (tester) async {
      await billWithCut(tester);
      await tester.tap(find.text('Pay later'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pumpAndSettle();
      expect(find.text('Paying now, ₹200 owed'), findsOneWidget);
      expect(find.text('₹100'), findsWidgets);
      expect(find.text('₹200'), findsOneWidget);
    });

    testWidgets('typing more than the bill pays it all, owing nothing', (tester) async {
      await billWithCut(tester);
      await tester.tap(find.text('Pay later'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '999');
      await tester.pumpAndSettle();
      expect(find.text('Still owed'), findsNothing);
    });
  });

  group('the pick screen', () {
    testWidgets('categories run down the side in menu order', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      expect(find.text('Facial'), findsOneWidget);
      expect(find.text('Threading'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Facial')).dy,
        lessThan(tester.getTopLeft(find.text('Threading')).dy),
      );
    });

    testWidgets('it opens on the first category, and a tap changes it', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      expect(find.text('Mens Cut'), findsOneWidget);
      await tester.tap(find.text('Facial'));
      await tester.pumpAndSettle();
      expect(find.text('Fruit Facial'), findsOneWidget);
      expect(find.text('Mens Cut'), findsNothing);
    });

    testWidgets('Popular leads once the salon has bills', (tester) async {
      final bill = Bill(
        id: 'b',
        invoiceNumber: 'INV',
        customerId: 'c1',
        branchId: 'b1',
        subTotal: 0,
        discountAmount: 0,
        taxAmount: 0,
        finalAmount: 0,
        paymentMethod: 'UPI',
        status: 'COMPLETED',
        items: [
          BillItem(
            id: 'i',
            type: 'SERVICE',
            serviceId: '3',
            quantity: 1,
            unitPrice: 0,
            discountAmount: 0,
            employeeId: 'e',
            calculatedCommission: 0,
          ),
        ],
      );
      await _pump(tester, _data(bills: [bill]));
      await _openPicker(tester);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Most billed'), findsOneWidget);
      expect(find.text('Fruit Facial'), findsOneWidget);
    });

    testWidgets('a picked service counts on its category', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Mens Cut'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('1 item added'), findsOneWidget);
    });

    testWidgets('Gents hides Ladies services and keeps ones for both', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.tap(find.text('Gents').first);
      await tester.pumpAndSettle();
      expect(find.text('Facial'), findsOneWidget);
      expect(find.text('Threading'), findsNothing);
    });

    testWidgets('searching lists matches across categories', (tester) async {
      await _pump(tester, _data());
      await _openPicker(tester);
      await tester.enterText(find.byType(TextField).first, 'eyebrow');
      await tester.pumpAndSettle();
      expect(find.text('Eyebrow'), findsOneWidget);
      expect(find.text('Facial'), findsNothing);
    });

    testWidgets('services saved before categories still show', (tester) async {
      final old = SalonService(id: '9', name: 'Old Service', price: 100, categoryId: '');
      await _pump(tester, _data(services: [old]));
      await _openPicker(tester);
      expect(find.text('Old Service'), findsOneWidget);
    });

    testWidgets('products have their own place', (tester) async {
      final gel = InventoryItem(
        id: 'p',
        sku: 's',
        name: 'Hair Gel',
        category: 'Styling',
        price: 250,
        costPrice: 100,
        stockCount: 10,
        minAlertThreshold: 2,
      );
      await _pump(tester, _data(inventory: [gel]));
      await _openPicker(tester);
      // Near the top of the list, but the screen still opens on services.
      expect(
        tester.getTopLeft(find.text('Products')).dy,
        lessThan(tester.getTopLeft(find.text('Cut with Wash').first).dy),
      );
      expect(find.text('Mens Cut'), findsOneWidget);
      await tester.tap(find.text('Products'));
      await tester.pumpAndSettle();
      expect(find.text('Hair Gel'), findsOneWidget);
    });

    testWidgets('long category names fit a small phone', (tester) async {
      await _pump(
        tester,
        _data(services: [_svc('1', 'Full Arms', 'Flavoured Waxing / Tan Remover')]),
        size: const Size(320, 640),
      );
      await _openPicker(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('prices settled on the bill', () {
    final tiers = SalonService(
      id: 'h',
      name: 'O3+',
      price: 2900,
      categoryId: 'c',
      categoryName: 'Hydra Facial',
      priceVaries: true,
      priceOptions: const [2900, 3400, 3900],
    );

    testWidgets('the list shows the range until a price is picked', (tester) async {
      await _pump(tester, _data(services: [tiers]));
      await _openPicker(tester);
      expect(find.text('₹2,900 - ₹3,900'), findsOneWidget);
      await tester.tap(find.text('O3+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('₹3,400'));
      await tester.pumpAndSettle();
      expect(find.text('₹2,900 - ₹3,900'), findsNothing);
      expect(find.text('₹3,400'), findsWidgets);
    });

    testWidgets('backing out leaves the service off the bill', (tester) async {
      await _pump(tester, _data(services: [tiers]));
      await _openPicker(tester);
      await tester.tap(find.text('O3+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing added yet'), findsOneWidget);
    });

    testWidgets('any amount can be typed', (tester) async {
      await _pump(tester, _data(services: [tiers]));
      await _openPicker(tester);
      await tester.tap(find.text('O3+'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Price for this client (₹)'), '3650');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('₹3,650'), findsWidgets);
    });
  });

  group('package credit on a bill', () {
    final cut = _svc('k', 'Haircut', 'Facial', price: 1000);
    ClientPackage credit(double balance, {DateTime? expires}) => ClientPackage(
          id: 'p',
          customerId: 'c1',
          paidAmount: 5000,
          creditValue: 6000,
          balance: balance,
          paymentMethod: 'UPI',
          expiresAt: expires ?? DateTime.now().add(const Duration(days: 30)),
        );

    Future<void> addCut(WidgetTester tester) async {
      await _openPicker(tester);
      await tester.tap(find.text('Haircut'));
      await tester.pumpAndSettle();
      await _done(tester);
    }

    testWidgets('a client with no package sees no credit', (tester) async {
      await _pump(tester, _data(services: [cut]), client: 'c1');
      expect(find.textContaining('package credit'), findsNothing);
    });

    testWidgets('credit covering the bill leaves nothing to choose', (tester) async {
      await _pump(tester, _data(services: [cut], packages: [credit(6000)]), client: 'c1');
      await addCut(tester);
      expect(find.text('₹6,000 package credit'), findsOneWidget);
      expect(find.text('Paid from package'), findsOneWidget);
      expect(find.text('-₹1,000'), findsOneWidget);
      expect(find.text('₹0'), findsWidgets);
      expect(find.text('Payment Method'), findsNothing);
    });

    testWidgets('credit short of the bill leaves the rest to pay', (tester) async {
      await _pump(tester, _data(services: [cut], packages: [credit(400)]), client: 'c1');
      await addCut(tester);
      expect(find.text('-₹400'), findsOneWidget);
      expect(find.text('₹600'), findsWidgets);
      expect(find.text('Payment Method'), findsOneWidget);
    });

    testWidgets('credit can be switched off for a bill', (tester) async {
      await _pump(tester, _data(services: [cut], packages: [credit(6000)]), client: 'c1');
      await addCut(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Paid from package'), findsNothing);
      expect(find.text('Payment Method'), findsOneWidget);
    });

    testWidgets('expired credit is not offered', (tester) async {
      final old = credit(6000, expires: DateTime.now().subtract(const Duration(days: 1)));
      await _pump(tester, _data(services: [cut], packages: [old]), client: 'c1');
      expect(find.textContaining('package credit'), findsNothing);
    });
  });

  group('the branch on History', () {
    Bill bill(String id, String client, String branch, double amount) => Bill(
          id: id,
          invoiceNumber: 'INV-$id',
          customerId: 'c1',
          customerName: client,
          branchId: branch,
          subTotal: amount,
          discountAmount: 0,
          taxAmount: 0,
          finalAmount: amount,
          paymentMethod: 'UPI',
          amountPaid: amount,
          status: 'COMPLETED',
          createdAt: DateTime.now(),
          items: const [],
        );
    final bills = [bill('1', 'Main Client', 'b1', 500), bill('2', 'Camp Client', 'b2', 200)];

    Future<void> openHistory(WidgetTester tester, AppData data) async {
      await _pump(tester, data);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester, String from, String to) async {
      await tester.tap(find.text(from));
      await tester.pumpAndSettle();
      await tester.tap(find.text(to).last);
      await tester.pumpAndSettle();
    }

    testWidgets('starts on all branches', (tester) async {
      await openHistory(tester, _data(bills: bills));
      expect(find.text('All branches'), findsOneWidget);
      expect(find.text('Main Client'), findsOneWidget);
      expect(find.text('Camp Client'), findsOneWidget);
      expect(find.text('₹700'), findsOneWidget);
    });

    testWidgets('choosing a branch narrows the bills and the money', (tester) async {
      await openHistory(tester, _data(bills: bills));
      await pick(tester, 'All branches', 'Camp');
      expect(find.text('Camp Client'), findsOneWidget);
      expect(find.text('Main Client'), findsNothing);
      expect(find.text('₹700'), findsNothing);
    });

    testWidgets('All branches brings everything back', (tester) async {
      await openHistory(tester, _data(bills: bills));
      await pick(tester, 'All branches', 'Camp');
      await pick(tester, 'Camp', 'All branches');
      expect(find.text('Main Client'), findsOneWidget);
    });

    testWidgets('browsing History leaves the new bill on its own branch', (tester) async {
      await openHistory(tester, _data(bills: bills));
      await pick(tester, 'All branches', 'Camp');
      await tester.tap(find.text('New Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Main Branch'), findsOneWidget);
    });

    testWidgets('one branch needs no filter', (tester) async {
      await openHistory(tester, _data(branches: [_branch('b1', 'Main Branch')], bills: bills));
      expect(find.text('All branches'), findsNothing);
    });
  });

  group('the branch switch', () {
    testWidgets('is in the header and picks the bill\'s branch', (tester) async {
      await _pump(tester, _data());
      expect(find.text('Branch:'), findsNothing);
      expect(find.text('Main Branch'), findsOneWidget);
      await tester.tap(find.text('Main Branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camp'));
      await tester.pumpAndSettle();
      expect(find.text('Camp'), findsOneWidget);
      expect(find.text('Main Branch'), findsNothing);
    });

    testWidgets('one branch needs no switch', (tester) async {
      await _pump(tester, _data(branches: [_branch('b1', 'Main Branch')]));
      expect(find.text('Main Branch'), findsNothing);
    });

    testWidgets('a long branch name fits a small phone', (tester) async {
      await _pump(
        tester,
        _data(branches: [_branch('b1', 'Vishram Bagh Main Road Branch'), _branch('b2', 'Camp')]),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('New on the pick screen opens the service form', (tester) async {
    await _pump(tester, _data());
    await _openPicker(tester);
    await tester.tap(find.byTooltip('Add a new service to the menu'));
    await tester.pumpAndSettle();
    expect(find.text('Add Service'), findsWidgets);
    expect(find.text('Both'), findsOneWidget);
    final category = find.ancestor(of: find.text('Category *'), matching: find.byType(InputDecorator)).first;
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);
  });
}
