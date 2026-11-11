import 'package:apexblocks/theme/themes.dart';
import 'package:apexblocks/ui/game_over_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Widget screen({
  int score = 120,
  int previousBest = 200,
  Widget? pitStop,
  VoidCallback? onNewRace,
  VoidCallback? onGarage,
}) => MaterialApp(
  home: GameOverScreen(
    theme: nightRace,
    score: score,
    previousBest: previousBest,
    linesCleared: 7,
    bestCombo: 3,
    piecesPlaced: 21,
    onNewRace: onNewRace ?? () {},
    onGarage: onGarage ?? () {},
    pitStop: pitStop,
  ),
);

void main() {
  testWidgets('shows LIVERY UNLOCKED with an Equip button', (tester) async {
    useScreen(tester, const Size(375, 667));
    int? equipped;
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverScreen(
          theme: nightRace,
          score: 120,
          previousBest: 200,
          linesCleared: 1,
          bestCombo: 1,
          piecesPlaced: 3,
          onNewRace: () {},
          onGarage: () {},
          newLiveries: const [1],
          onEquip: (i) => equipped = i,
        ),
      ),
    );
    expect(find.text('LIVERY UNLOCKED · RAIN RACE'), findsOneWidget);
    await tester.tap(find.text('Equip'));
    expect(equipped, 1);
  });

  for (final size in phoneSizes) {
    testWidgets('fits $size', (tester) async {
      useScreen(tester, size);
      await tester.pumpWidget(screen());
      expect(tester.takeException(), isNull);
      for (final label in ['NEW RACE', 'GARAGE']) {
        final h = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(h.height, greaterThanOrEqualTo(44));
      }
    });
  }

  testWidgets('shows how far the score is from pole', (tester) async {
    await tester.pumpWidget(screen(score: 120, previousBest: 200));
    expect(find.text('CHEQUERED FLAG'), findsOneWidget);
    expect(find.text('No room left on the grid'), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('POLE 200'), findsOneWidget);
    expect(find.text('81 to beat it'), findsOneWidget);
    expect(find.text('NEW POLE!'), findsNothing);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
  });

  testWidgets('a beaten pole says NEW POLE!', (tester) async {
    await tester.pumpWidget(screen(score: 250, previousBest: 200));
    expect(find.text('NEW POLE!'), findsOneWidget);
    expect(find.text('POLE 250'), findsOneWidget);
    expect(find.textContaining('to beat it'), findsNothing);
  });

  testWidgets('a tied pole is not a new pole', (tester) async {
    await tester.pumpWidget(screen(score: 200, previousBest: 200));
    expect(find.text('NEW POLE!'), findsNothing);
    expect(find.text('1 to beat it'), findsOneWidget);
  });

  testWidgets('no pit stop unless one is supplied', (tester) async {
    await tester.pumpWidget(screen());
    expect(find.textContaining('PIT STOP'), findsNothing);
    expect(find.text('One pit stop per race'), findsNothing);
  });

  testWidgets('buttons call back', (tester) async {
    var race = 0, garage = 0;
    await tester.pumpWidget(
      screen(onNewRace: () => race++, onGarage: () => garage++),
    );
    await tester.tap(find.text('NEW RACE'));
    await tester.tap(find.text('GARAGE'));
    expect([race, garage], [1, 1]);
  });
}
