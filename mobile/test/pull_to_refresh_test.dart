// Swipe down to reload on the main tabs (widgets/pull_to_refresh.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/pull_to_refresh.dart';

Future<int Function()> _pump(WidgetTester tester, Widget page) async {
  var pulls = 0;
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: PullToRefresh(
          onRefresh: () async => pulls++,
          child: page,
        ),
      ),
    ),
  ));
  return () => pulls;
}

void main() {
  testWidgets('pulling down a nearly empty tab reloads', (tester) async {
    // Shorter than the screen and with no physics of its own - the case
    // that can't be pulled without always-scrollable physics.
    final pulls = await _pump(
      tester,
      const SingleChildScrollView(child: Text('No clients yet.')),
    );
    await tester.fling(find.text('No clients yet.'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(pulls(), 1);
  });

  testWidgets('a list nested inside the tab still triggers it', (tester) async {
    final pulls = await _pump(
      tester,
      Column(
        children: [
          const Text('Header'),
          Expanded(child: ListView(children: const [Text('Row 1'), Text('Row 2')])),
        ],
      ),
    );
    await tester.fling(find.text('Row 1'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(pulls(), 1);
  });

  testWidgets('sideways scrolling (filter chips) does not reload', (tester) async {
    final pulls = await _pump(
      tester,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (var i = 0; i < 20; i++) Text('Chip $i  ')]),
      ),
    );
    await tester.fling(find.text('Chip 2  '), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(pulls(), 0);
  });
}
