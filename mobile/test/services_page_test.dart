// Menu > Services: the same side list as the Add services screen. Pumped on a
// stub snapshot, so no Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
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

InventoryItem _item(String id, String name, int stock) => InventoryItem(
      id: id,
      sku: 'sku-$id',
      name: name,
      category: 'Styling',
      price: 250,
      costPrice: 100,
      stockCount: stock,
      minAlertThreshold: 5,
    );

AppData _data({List<SalonService>? services, List<InventoryItem> inventory = const []}) => AppData(
      branches: const [],
      employees: const [],
      customers: const [],
      categories: const [],
      services: services ??
          [
            _svc('1', 'Mens Cut', 'Cut with Wash', audience: kAudienceGents),
            _svc('2', 'Eyebrow', 'Threading', audience: kAudienceLadies),
            _svc('3', 'Fruit Facial', 'Facial'),
          ],
      inventory: inventory,
      bills: const [],
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

Future<void> _pump(WidgetTester tester, AppData data, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDataProvider.overrideWith(() => _Stub(data))],
      child: const MaterialApp(home: Scaffold(body: OwnerInventoryTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the first category, not the whole menu', (tester) async {
    await _pump(tester, _data());
    expect(find.text('Mens Cut'), findsOneWidget);
    expect(find.text('Fruit Facial'), findsNothing);
    expect(find.text('Eyebrow'), findsNothing);
  });

  testWidgets('a category on the left opens on the right', (tester) async {
    await _pump(tester, _data());
    await tester.tap(find.text('Facial'));
    await tester.pumpAndSettle();
    expect(find.text('Fruit Facial'), findsOneWidget);
    expect(find.text('Mens Cut'), findsNothing);
  });

  testWidgets('Ladies hides Gents services and keeps ones for both', (tester) async {
    await _pump(tester, _data());
    await tester.tap(find.text('Ladies'));
    await tester.pumpAndSettle();
    expect(find.text('Cut with Wash'), findsNothing);
    expect(find.text('Facial'), findsWidgets);
    expect(find.text('Threading'), findsOneWidget);
  });

  testWidgets('searching finds services and products across categories', (tester) async {
    await _pump(tester, _data(inventory: [_item('p', 'Hair Gel', 10)]));
    await tester.enterText(find.byType(TextField).first, 'e');
    await tester.pumpAndSettle();
    expect(find.text('Eyebrow'), findsOneWidget);
    expect(find.text('Hair Gel'), findsOneWidget);
  });

  testWidgets('a search with no match says so', (tester) async {
    await _pump(tester, _data());
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches "zzz"'), findsOneWidget);
  });

  testWidgets('tapping a service opens its edit form', (tester) async {
    await _pump(tester, _data());
    await tester.tap(find.text('Mens Cut'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Service'), findsOneWidget);
  });

  testWidgets('products are near the top, and it still opens on services', (tester) async {
    await _pump(tester, _data(inventory: [_item('p', 'Hair Gel', 10)]));
    expect(
      tester.getTopLeft(find.text('Products')).dy,
      lessThan(tester.getTopLeft(find.text('Cut with Wash').first).dy),
    );
    expect(find.text('Mens Cut'), findsOneWidget);
  });

  testWidgets('products keep their stock and Update stock', (tester) async {
    await _pump(tester, _data(inventory: [_item('p', 'Hair Gel', 10)]));
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Hair Gel'), findsOneWidget);
    expect(find.text('10 units in stock'), findsOneWidget);
    expect(find.text('Update stock'), findsOneWidget);
  });

  testWidgets('no low stock, no Low stock entry', (tester) async {
    await _pump(tester, _data(inventory: [_item('p', 'Hair Gel', 10)]));
    expect(find.text('Low stock'), findsNothing);
  });

  testWidgets('low stock has its own place', (tester) async {
    await _pump(tester, _data(inventory: [_item('p', 'Hair Gel', 10), _item('q', 'Wax', 2)]));
    await tester.tap(find.text('Low stock'));
    await tester.pumpAndSettle();
    expect(find.text('Wax'), findsOneWidget);
    expect(find.text('Hair Gel'), findsNothing);
  });

  testWidgets('a price that varies says so', (tester) async {
    final consult = SalonService(
      id: 'v',
      name: 'Botox',
      price: 0,
      categoryId: 'c',
      categoryName: 'Hair Treatment',
      priceVaries: true,
    );
    await _pump(tester, _data(services: [consult]));
    expect(find.text('On consultation'), findsOneWidget);
  });

  testWidgets('an empty menu says what to do', (tester) async {
    await _pump(tester, _data(services: const []));
    expect(find.text('No services yet - tap Add to build your menu.'), findsOneWidget);
  });

  testWidgets('long names fit a small phone', (tester) async {
    await _pump(
      tester,
      _data(
        services: [_svc('1', 'Body Polish Signature Treatment (Cleansing + Scrub + Massage + Pack)', 'Flavoured Waxing / Tan Remover', price: 4500)],
        inventory: [_item('p', 'A very long product name that keeps going', 2)],
      ),
      size: const Size(320, 640),
    );
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
