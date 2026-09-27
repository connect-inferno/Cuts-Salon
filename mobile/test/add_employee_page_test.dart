// Creating a staff account sets a login, a roster entry and a pay agreement
// in one go. Two things there are worth pinning: the commission labels must
// be readable (the dialog this replaced clipped them to "Service Com..." and
// "Product Com...", which are the numbers that decide what someone is paid),
// and the validation has to survive the rewrite.
//
// The page only touches appDataProvider on the success path, so everything
// below runs under a bare ProviderScope and never reaches Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/data/models.dart';
import 'package:mobile/features/owner/widgets/add_employee_page.dart';

Branch _branch(String id, String name) => Branch(
      id: id,
      name: name,
      active: true,
      employeeCount: 0,
      customerCount: 0,
      monthlyRevenue: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Branch>? branches,
  Size size = const Size(375, 812),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AddEmployeePage(
            assignableBranches: branches ?? [_branch('b1', 'Vishram bagh')],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inPreview(String text) => find.descendant(
      of: find.byKey(const Key('addEmployeePreview')),
      matching: find.text(text),
    );

Future<void> _fillRequired(WidgetTester tester, {String password = 'longenough1'}) async {
  await tester.enterText(find.byType(TextField).at(0), 'Jamie Davis');
  await tester.enterText(find.byType(TextField).at(1), '9876543210');
  await tester.enterText(find.byType(TextField).at(3), 'jamie@salon.com');
  await tester.enterText(find.byType(TextField).at(4), password);
  await tester.pump();
}

void main() {
  group('commission labels', () {
    for (final size in const [Size(320, 640), Size(375, 812)]) {
      testWidgets('are shown in full at ${size.width.toInt()}px', (tester) async {
        await _pump(tester, size: size);

        // The whole point of the rewrite: these two were clipped to
        // "Service Com..." / "Product Com..." in the dialog.
        expect(find.text('Service Commission (%)'), findsOneWidget);
        expect(find.text('Product Commission (%)'), findsOneWidget);
      });
    }
  });

  testWidgets('groups the form into its three decisions', (tester) async {
    await _pump(tester);

    expect(find.text('Who they are'), findsOneWidget);
    expect(find.text('How they sign in'), findsOneWidget);
    expect(find.text('Branch and pay'), findsOneWidget);
  });

  testWidgets('preview fills in from the name and role', (tester) async {
    await _pump(tester);

    expect(find.text('New team member'), findsOneWidget);
    // The role field is pre-filled, so it already shows in the preview.
    expect(_inPreview('Hair Stylist'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Jamie Davis');
    await tester.pump();

    expect(_inPreview('Jamie Davis'), findsOneWidget);
    expect(_inPreview('JD'), findsOneWidget);
  });

  testWidgets('shows what the service rate actually pays', (tester) async {
    await _pump(tester);

    // Defaults to 15%, so a typo like 1.5 is visible as a rupee figure
    // before the pay terms are saved.
    expect(find.text('On ₹1,000 of services they earn ₹150'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(6), '30');
    await tester.pump();

    expect(find.text('On ₹1,000 of services they earn ₹300'), findsOneWidget);
  });

  group('validation', () {
    testWidgets('an empty form is rejected', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Name, email, and phone are required.'),
        findsOneWidget,
      );
    });

    testWidgets('a short password is rejected', (tester) async {
      await _pump(tester);
      await _fillRequired(tester, password: 'short');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('the password rule reports progress as you type',
        (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField).at(4), 'abc');
      await tester.pump();
      expect(find.text('5 more characters needed'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(4), 'abcdefg');
      await tester.pump();
      expect(find.text('1 more character needed'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(4), 'abcdefgh');
      await tester.pump();
      expect(find.text('Long enough'), findsOneWidget);
    });
  });

  testWidgets('the password can be revealed and hidden', (tester) async {
    await _pump(tester);

    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).at(4));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
  });

  group('branch', () {
    testWidgets('a single branch is preselected', (tester) async {
      await _pump(tester);
      expect(find.text('Vishram bagh'), findsOneWidget);
    });

    testWidgets('several branches are all offered and switchable',
        (tester) async {
      await _pump(tester, branches: [
        _branch('b1', 'Vishram bagh'),
        _branch('b2', 'Camp'),
        _branch('b3', 'Kothrud'),
      ]);

      expect(find.text('Vishram bagh'), findsOneWidget);
      expect(find.text('Camp'), findsOneWidget);
      expect(find.text('Kothrud'), findsOneWidget);

      // Tapping another branch must not throw or drop the others.
      await tester.tap(find.text('Kothrud'));
      await tester.pumpAndSettle();
      expect(find.text('Kothrud'), findsOneWidget);
    });

    testWidgets('many branches wrap instead of overflowing', (tester) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        branches: [
          for (var i = 0; i < 6; i++) _branch('b$i', 'Branch Number $i'),
        ],
      );

      expect(find.text('Branch Number 5'), findsOneWidget);
    });
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
                    builder: (_) => Scaffold(
                      body: AddEmployeePage(
                        assignableBranches: [_branch('b1', 'Main')],
                      ),
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
    expect(find.text('Who they are'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Who they are'), findsNothing);
  });
}
