// The Branches tab rendered as a blank page: the header, the section pills
// and the "3 branches" line were all there, and everything below them was
// empty.
//
// The cause was a Row with crossAxisAlignment: stretch inside a Column inside
// a SingleChildScrollView. A Row's cross axis is vertical, so there it is
// handed maxHeight: infinity, and stretch tries to size its children to that
// - which throws during layout. main.dart installs a FlutterError.onError
// that logs without calling presentError (deliberately, so the red overlay
// cannot block the UI), so the exception never reached the screen and the
// tab just came up empty.
//
// That combination - a layout error that is invisible at runtime - is worth a
// test, because the next one will be invisible too.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/owner_management_tabs.dart';

Branch _branch(String id, String name, {int staff = 4, double revenue = 125000}) =>
    Branch(
      id: id,
      name: name,
      address: '12 Example Road',
      phone: '9876543210',
      active: true,
      employeeCount: staff,
      customerCount: 87,
      monthlyRevenue: revenue,
    );

AppData _appData(List<Branch> branches) => AppData(
      branches: branches,
      employees: const [],
      customers: const [],
      categories: const [],
      services: const [],
      inventory: const [],
      bills: const [],
      discountRequests: const [],
      salesTargets: const [],
      commissions: const [],
      attendance: const [],
      dashboard: null,
      settings: null,
    );

/// Serves a fixed snapshot so the tab can be pumped without Firebase.
class _StubAppData extends AppDataNotifier {
  _StubAppData(this._data);
  final AppData _data;

  @override
  Future<AppData> build() async => _data;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<Branch> branches,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith(() => _StubAppData(_appData(branches))),
      ],
      child: const MaterialApp(home: Scaffold(body: OwnerBranchTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every branch instead of coming up blank', (tester) async {
    await _pump(tester, branches: [
      _branch('b1', 'Vishram bagh'),
      _branch('b2', 'Camp'),
      _branch('b3', 'Kothrud'),
    ]);

    // All three cards present - this is the reported symptom: the count said
    // three and the list showed none.
    expect(find.text('Vishram bagh'), findsOneWidget);
    expect(find.text('Camp'), findsOneWidget);
    expect(find.text('Kothrud'), findsOneWidget);

    // And the stat boxes inside the card that actually threw.
    expect(find.text('Served'), findsNWidgets(3));
    expect(find.text('Staff'), findsNWidgets(3));
    expect(find.text('Rev/Emp'), findsNWidgets(3));
  });

  testWidgets('a single branch renders', (tester) async {
    await _pump(tester, branches: [_branch('b1', 'Only Branch')]);
    expect(find.text('Only Branch'), findsOneWidget);
  });

  testWidgets('renders at a narrow width', (tester) async {
    // The stat row is three boxes across a third of the screen each, which is
    // where the previous layout was already clipping values.
    await _pump(
      tester,
      size: const Size(320, 640),
      branches: [_branch('b1', 'Vishram bagh', staff: 12, revenue: 1250000)],
    );

    expect(find.text('Vishram bagh'), findsOneWidget);
    expect(find.text('Rev/Emp'), findsOneWidget);
  });

  testWidgets('no branches does not throw', (tester) async {
    await _pump(tester, branches: const []);
    expect(find.byType(OwnerBranchTab), findsOneWidget);
  });
}
