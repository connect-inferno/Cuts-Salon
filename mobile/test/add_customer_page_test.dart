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

void main() {
  testWidgets('shows the three client fields', (tester) async {
    await _pump(tester);

    expect(find.text('Full Name *'), findsOneWidget);
    expect(find.text('Phone Number *'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Customer'));
    await tester.pump(); // let the SnackBar in

    expect(find.text('Name and phone are required.'), findsOneWidget);
    // Still on the page - reaching the provider would have thrown here,
    // since nothing is overridden.
    expect(find.text('Full Name *'), findsOneWidget);
  });

  testWidgets('a name without a phone is still rejected', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Priya');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Customer'));
    await tester.pump();

    expect(find.text('Name and phone are required.'), findsOneWidget);
  });

  testWidgets('whitespace is not accepted as a name', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Customer'));
    await tester.pump();

    expect(find.text('Name and phone are required.'), findsOneWidget);
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
    expect(find.text('Full Name *'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Full Name *'), findsNothing);
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

    await tester.enterText(find.byType(TextField).first, 'Priya Sharma');
    await tester.pump();

    expect(find.text('New client'), findsNothing);
    expect(_inPreview('Priya Sharma'), findsOneWidget);
    // Two-letter initials, matching the avatar the directory will show.
    expect(_inPreview('PS'), findsOneWidget);
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
      find.textContaining('visits and spend start tracking'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(1), '9876543210');
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
      await tester.enterText(
        find.byType(TextField).first,
        'Bhuvaneshwari Ramachandran Venkataraman',
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Add Customer'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    });
  }
}
