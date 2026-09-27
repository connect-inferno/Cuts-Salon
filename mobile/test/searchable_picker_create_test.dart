// The customer picker in both POS screens grew an "add new customer" action.
// The subtle part is what happens after: the sheet stays open while the add
// flow runs on top of it, then closes returning the new record, so the caller
// selects it exactly as if it had been picked from the list. Backing out of
// the add flow must leave the picker open instead of cancelling the pick.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/widgets/searchable_picker.dart';

/// Opens the picker from a button and records what it resolved with.
Future<void> _pumpPicker(
  WidgetTester tester, {
  required List<String> items,
  Future<String?> Function(BuildContext)? onCreate,
  required void Function(String?) onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final picked = await showSearchablePicker<String>(
                context: context,
                title: 'Select Customer',
                items: items,
                labelOf: (s) => s,
                onCreate: onCreate,
                createLabel: 'Add new customer',
              );
              onResult(picked);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no create action unless onCreate is given', (tester) async {
    await _pumpPicker(
      tester,
      items: ['Priya'],
      onResult: (_) {},
    );

    expect(find.text('Add new customer'), findsNothing);
    expect(find.text('Select Customer'), findsOneWidget);
  });

  testWidgets('the create action shows when onCreate is given', (tester) async {
    await _pumpPicker(
      tester,
      items: ['Priya'],
      onCreate: (_) async => 'New Client',
      onResult: (_) {},
    );

    expect(find.text('Add new customer'), findsOneWidget);
  });

  testWidgets('creating resolves the picker with the new record',
      (tester) async {
    String? result;
    await _pumpPicker(
      tester,
      items: ['Priya'],
      onCreate: (_) async => 'New Client',
      onResult: (r) => result = r,
    );

    await tester.tap(find.text('Add new customer'));
    await tester.pumpAndSettle();

    // Sheet closed, and the new record came back as the pick - the caller
    // does not have to search for the name it just created.
    expect(result, 'New Client');
    expect(find.text('Select Customer'), findsNothing);
  });

  testWidgets('backing out of create leaves the picker open', (tester) async {
    String? result;
    var resolved = false;
    await _pumpPicker(
      tester,
      items: ['Priya'],
      onCreate: (_) async => null, // user cancelled the add page
      onResult: (r) {
        resolved = true;
        result = r;
      },
    );

    await tester.tap(find.text('Add new customer'));
    await tester.pumpAndSettle();

    // Still picking. Cancelling the add must not cancel the whole selection.
    expect(find.text('Select Customer'), findsOneWidget);
    expect(resolved, isFalse);

    await tester.tap(find.text('Priya'));
    await tester.pumpAndSettle();
    expect(result, 'Priya');
  });

  testWidgets('an empty list still offers the create action', (tester) async {
    // The first client a salon ever adds has to be reachable from here: the
    // employee POS used to refuse to open this sheet when the list was empty.
    await _pumpPicker(
      tester,
      items: const [],
      onCreate: (_) async => 'First Client',
      onResult: (_) {},
    );

    expect(find.text('Add new customer'), findsOneWidget);
    expect(find.textContaining('add them above'), findsOneWidget);
  });

  testWidgets('picking from the list still works unchanged', (tester) async {
    String? result;
    await _pumpPicker(
      tester,
      items: ['Priya', 'Verification Test'],
      onCreate: (_) async => 'New Client',
      onResult: (r) => result = r,
    );

    await tester.tap(find.text('Verification Test'));
    await tester.pumpAndSettle();

    expect(result, 'Verification Test');
  });
}
