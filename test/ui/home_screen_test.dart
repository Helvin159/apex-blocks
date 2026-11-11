import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final size in phoneSizes) {
    testWidgets('fits $size', (tester) async {
      useScreen(tester, size);
      final storage = await makeStorage({'bestScore': 1234567});
      await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
      expect(tester.takeException(), isNull);
      final button = find.ancestor(
        of: find.text('LIGHTS OUT →'),
        matching: find.byType(FilledButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('shows round, pole and livery progress', (tester) async {
    final storage = await makeStorage({
      'gamesPlayed': 6,
      'bestScore': 4821,
      'careerPoints': 3240,
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    expect(find.text('ROUND 7 · NIGHT RACE'), findsOneWidget);
    expect(find.text('4,821'), findsOneWidget);
    expect(find.text('3,240 / 5,000 pts'), findsOneWidget);
    expect(find.text('3,240 / 15,000 pts'), findsOneWidget);
    expect(find.text('EQUIPPED'), findsOneWidget);
    expect(find.text('APEX'), findsOneWidget);
    expect(find.text('BLOCKS'), findsOneWidget);
    expect(find.text('ENDLESS BLOCK RACING'), findsOneWidget);
  });

  testWidgets('hides buttons that have no screen yet', (tester) async {
    final storage = await makeStorage();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    expect(find.textContaining('SETUP'), findsNothing);
    expect(find.textContaining('CLEAN AIR'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('LIGHTS OUT starts a run; the Home screen refreshes after', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump(const Duration(seconds: 3)); // the start lights
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);

    await storage.recordRun(500);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('ROUND 2 · NIGHT RACE'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
  });
}
