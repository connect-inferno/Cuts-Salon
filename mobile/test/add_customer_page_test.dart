// Add Customer moved from a dialog to its own page, and the VIP toggle was
// removed. Both are easy to regress by accident - a stray re-add of the
// switch, or the validation guard getting dropped when the submit button was
// rewired - and neither is visible without signing in to the app.
//
// The page only touches appDataProvider on the success path, so everything
// below runs under a bare ProviderScope with no overrides and never reaches
// Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/app_data.dart';
import 'package:mobile/data/app_data_provider.dart';
import 'package:mobile/data/models.dart';
import 'package:mobile/widgets/add_customer_page.dart';

Branch _branch(String id, String name) => Branch(
      id: id,
      name: name,
      active: true,
      employeeCount: 0,
      customerCount: 0,
      monthlyRevenue: 0,
    );

/// The preview card renders the same name and phone the fields hold, so
/// assertions about it have to say which copy they mean.
Finder _inPreview(String text) => find.descendant(
      of: find.byKey(const Key('addCustomerPreview')),
      matching: find.text(text),
    );

Future<void> _pump(WidgetTester tester, {List<Branch> branches = const []}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: AddCustomerPage(branches: branches)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _priya = Customer(
  id: 'c1',
  name: 'Priya Kumari Sharma',
  phone: '9876543210',
  email: 'priya@example.com',
  gender: 'F',
  isVip: false,
  branchId: 'b1',
  visitCount: 7,
  birthday: '03-14',
  whatsappOptIn: true,
);

/// Records what Edit client saves instead of writing to Firestore.
class _EditStub extends AppDataNotifier {
  final List<Map<String, Object?>> saved = [];

  @override
  Future<AppData> build() async => AppData(
        branches: const [],
        employees: const [],
        customers: [_priya],
        categories: const [],
        services: const [],
        inventory: const [],
        bills: const [],
        salesTargets: const [],
        commissions: const [],
        attendance: const [],
        dashboard: null,
        settings: null,
      );

  @override
  Future<Customer> updateCustomer(String id,
      {required String name,
      required String phone,
      String? email,
      String? gender,
      String? birthday,
      required bool whatsappOptIn}) async {
    saved.add({'id': id, 'name': name, 'phone': phone, 'email': email, 'gender': gender, 'birthday': birthday, 'whatsappOptIn': whatsappOptIn});
    return _priya;
  }
}

Future<_EditStub> _pumpEdit(WidgetTester tester, Customer existing) async {
  final stub = _EditStub();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDataProvider.overrideWith(() => stub)],
      child: MaterialApp(
        home: Scaffold(body: AddCustomerPage(branches: const [], existing: existing)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return stub;
}

void main() {
  group('edit client', () {
    testWidgets('opens filled in, with the name split into its parts', (tester) async {
      await _pumpEdit(tester, _priya);
      expect(find.widgetWithText(TextField, 'Priya'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Kumari'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sharma'), findsOneWidget);
      expect(find.widgetWithText(TextField, '9876543210'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'priya@example.com'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.textContaining('Past bills keep the name'), findsOneWidget);
    });

    testWidgets('saves the changed details, keeping gender and birthday', (tester) async {
      final stub = await _pumpEdit(tester, _priya);
      await tester.enterText(find.widgetWithText(TextField, 'Sharma'), 'Verma');
      await tester.enterText(find.widgetWithText(TextField, '9876543210'), '9123456780');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(stub.saved, [
        {
          'id': 'c1',
          'name': 'Priya Kumari Verma',
          'phone': '9123456780',
          'email': 'priya@example.com',
          'gender': 'FEMALE',
          'birthday': '03-14',
          'whatsappOptIn': true,
        },
      ]);
    });

    testWidgets('a client saved with one name can still be saved', (tester) async {
      final stub = await _pumpEdit(
        tester,
        Customer(id: 'c2', name: 'Ravi', phone: '9000000001', isVip: false, branchId: 'b1'),
      );
      expect(find.text('Last Name'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(stub.saved.single['name'], 'Ravi');
    });
  });

  testWidgets('shows the client fields, with the name in three parts', (tester) async {
    await _pump(tester);

    expect(find.text('First Name *'), findsOneWidget);
    expect(find.text('Middle Name'), findsOneWidget);
    expect(find.text('Last Name *'), findsOneWidget);
    expect(find.text('Phone Number *'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
  });

  testWidgets('gender is a Male / Female choice that can be cleared', (tester) async {
    await _pump(tester);

    expect(find.text('Gender'), findsOneWidget);
    Color textColor(String label) => tester.widget<Text>(find.text(label)).style!.color!;
    final unpicked = textColor('Female');

    await tester.tap(find.byKey(const Key('genderFemale')));
    await tester.pump();
    expect(textColor('Female'), isNot(unpicked));
    expect(textColor('Male'), unpicked);

    await tester.tap(find.byKey(const Key('genderMale')));
    await tester.pump();
    expect(textColor('Female'), unpicked);
    expect(textColor('Male'), isNot(unpicked));

    // Optional: tapping the picked one again un-picks it.
    await tester.tap(find.byKey(const Key('genderMale')));
    await tester.pump();
    expect(textColor('Male'), unpicked);
  });

  testWidgets('has no VIP toggle', (tester) async {
    await _pump(tester);

    // Both the widget and the label - a re-add under a different control
    // should still trip this.
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('VIP'), findsNothing);
  });

  testWidgets('submitting with empty fields warns and does not proceed',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add client'));
    await tester.pump(); // let the SnackBar in

    expect(find.text('Please add the first name, last name and phone number.'), findsOneWidget);
    // Still on the page - reaching the provider would have thrown here,
    // since nothing is overridden.
    expect(find.text('First Name *'), findsOneWidget);
  });

  testWidgets('a name without a phone is still rejected', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Priya');
    await tester.enterText(find.byType(TextField).at(2), 'Sharma');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add client'));
    await tester.pump();

    expect(find.text('Please add the phone number.'), findsOneWidget);
  });

  testWidgets('the last name is required, the middle name is not', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Priya');
    await tester.enterText(find.byType(TextField).at(1), 'Kumari');
    await tester.enterText(find.byType(TextField).at(3), '9876543210');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add client'));
    await tester.pump();

    expect(find.text('Please add the last name.'), findsOneWidget);
  });

  testWidgets('whitespace is not accepted as a name', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.enterText(find.byType(TextField).at(3), '9876543210');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add client'));
    await tester.pump();

    expect(find.text('Please add the first name and last name.'), findsOneWidget);
  });

  testWidgets('Cancel closes the page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: AddCustomerPage(branches: []),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('First Name *'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('First Name *'), findsNothing);
  });

  testWidgets('the branch-sharing note only appears with several branches',
      (tester) async {
    await _pump(tester);
    expect(find.textContaining('shared across all branches'), findsNothing);

    await _pump(tester, branches: [
      _branch('b1', 'Main'),
      _branch('b2', 'Second'),
    ]);
    expect(find.textContaining('shared across all branches'), findsOneWidget);
  });

  testWidgets('preview card fills in from the name as it is typed',
      (tester) async {
    await _pump(tester);

    // Before anything is typed it is a placeholder, not a blank avatar.
    expect(find.text('New client'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'priya');
    await tester.enterText(find.byType(TextField).at(2), 'sharma');
    await tester.pump();

    expect(find.text('New client'), findsNothing);
    // Joined into one name, each part starting with a capital.
    expect(_inPreview('Priya Sharma'), findsOneWidget);
    // Two-letter initials, matching the avatar the directory will show.
    expect(_inPreview('PS'), findsOneWidget);
  });

  testWidgets('a middle name goes between first and last', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Priya');
    await tester.enterText(find.byType(TextField).at(1), '  kumari ');
    await tester.enterText(find.byType(TextField).at(2), 'Sharma');
    await tester.pump();

    expect(_inPreview('Priya Kumari Sharma'), findsOneWidget);
  });

  testWidgets('a single-word name yields one initial', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'madonna');
    await tester.pump();

    expect(_inPreview('M'), findsOneWidget);
  });

  testWidgets('the preview shows the phone once it is entered', (tester) async {
    await _pump(tester);

    expect(
      find.textContaining('Visits and spend are tracked'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(3), '9876543210');
    await tester.pump();

    expect(_inPreview('9876543210'), findsOneWidget);
  });

  for (final entry in const {'narrow': Size(320, 640), 'phone': Size(375, 812)}
      .entries) {
    testWidgets('lays out without overflow at ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A long name is the realistic worst case for the preview row and for
      // the gradient button beside Cancel.
      await _pump(tester, branches: [_branch('b1', 'Main'), _branch('b2', 'Two')]);
      await tester.enterText(find.byType(TextField).first, 'Bhuvaneshwari');
      await tester.enterText(find.byType(TextField).at(1), 'Ramachandran');
      await tester.enterText(find.byType(TextField).at(2), 'Venkataraman');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Add client'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });
  }
}
