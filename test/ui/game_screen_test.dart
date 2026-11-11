import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexblocks/ui/board_geometry.dart';
import 'package:apexblocks/ui/board_view.dart';
import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/services/storage_service.dart';
import 'package:apexblocks/ui/game_over_screen.dart';
import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/ui/tray_view.dart';

import 'test_support.dart';

Future<StorageService> pumpScreen(
  WidgetTester tester,
  Size size, {
  Map<String, Object> prefs = const {},
  GameState Function()? newGame,
}) async {
  useScreen(tester, size);
  final storage = await makeStorage(prefs);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(storage: storage, newGame: newGame ?? GameState.new),
    ),
  );
  return storage;
}

/// The big number in the SCORE box.
String scoreOf(WidgetTester tester) {
  final column = find
      .ancestor(of: find.text('SCORE'), matching: find.byType(Column))
      .first;
  final texts = find.descendant(of: column, matching: find.byType(Text));
  return tester.widget<Text>(texts.at(1)).data!;
}

Finder get slots =>
    find.descendant(of: find.byType(TrayView), matching: find.byType(Listener));

/// Drags tray slot [slot] to the board center (the piece fits there on an
/// empty board) and releases.
Future<void> dragToBoardCenter(WidgetTester tester, int slot) async {
  final geometry = tester.widget<BoardView>(find.byType(BoardView)).geometry;
  final target =
      tester.getCenter(find.byType(BoardView)) +
      Offset(0, dragLiftCells * geometry.step);
  final gesture = await tester.startGesture(tester.getCenter(slots.at(slot)));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(target / 2 + tester.getCenter(slots.at(slot)) / 2);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Drags tray slot [slot] onto board cell ([row], [col]) and releases.
Future<void> dragToCell(WidgetTester tester, int slot, int row, int col) async {
  final board = tester.widget<BoardView>(find.byType(BoardView));
  final geometry = board.geometry;
  final target =
      tester.getTopLeft(find.byType(BoardView)) +
      geometry.cellRect(row, col).center +
      Offset(0, dragLiftCells * geometry.step);
  final start = tester.getCenter(slots.at(slot));
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo((start + target) / 2);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final size in phoneSizes) {
    testWidgets('fits $size with 44px+ tray slots', (tester) async {
      await pumpScreen(tester, size);
      expect(tester.takeException(), isNull);
      expect(slots, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final s = tester.getSize(slots.at(i));
        expect(s.width, greaterThanOrEqualTo(44));
        expect(s.height, greaterThanOrEqualTo(44));
      }
      final screen = Offset.zero & size;
      expect(
        screen.contains(tester.getBottomRight(find.byType(TrayView))),
        isTrue,
      );
      final board = tester.getRect(find.byType(BoardView));
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(size.width));
      expect(
        board.bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TrayView)).dy),
      );
    });
  }

  testWidgets('a valid drop places the piece and scores', (tester) async {
    await pumpScreen(tester, const Size(375, 667));
    expect(scoreOf(tester), '0');
    await dragToBoardCenter(tester, 0);
    expect(scoreOf(tester), isNot('0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invalid drop returns the piece to its slot', (tester) async {
    await pumpScreen(tester, const Size(375, 667));
    final gesture = await tester.startGesture(tester.getCenter(slots.at(1)));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scoreOf(tester), '0');

    // The slot is usable again: dropping it on the board now scores.
    await dragToBoardCenter(tester, 1);
    expect(scoreOf(tester), isNot('0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('header: 44px menu button, score and pole boxes', (tester) async {
    await pumpScreen(tester, const Size(320, 568), prefs: {'bestScore': 900});
    final menu = tester.getSize(find.byTooltip('Menu'));
    expect(menu.width, greaterThanOrEqualTo(44));
    expect(menu.height, greaterThanOrEqualTo(44));
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('POLE'), findsOneWidget);
    expect(find.text('900'), findsOneWidget);
  });

  testWidgets('pause sheet: resume keeps the game, restart resets it', (
    tester,
  ) async {
    await pumpScreen(tester, const Size(375, 667));
    await dragToBoardCenter(tester, 0);
    expect(scoreOf(tester), isNot('0'));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    for (final label in ['RESUME', 'RESTART', 'GARAGE']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(44));
    }
    await tester.tap(find.text('RESUME'));
    await tester.pumpAndSettle();
    expect(find.text('RESUME'), findsNothing);
    expect(scoreOf(tester), isNot('0'));

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESTART'));
    await tester.pumpAndSettle();
    expect(scoreOf(tester), '0');
  });

  testWidgets('pause sheet: garage leaves the game screen', (tester) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(storage: storage),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(storage.gamesPlayed, 0);
  });

  testWidgets('game over shows the flag and books the run exactly once', (
    tester,
  ) async {
    final storage = await pumpScreen(
      tester,
      const Size(375, 667),
      prefs: {'bestScore': 50, 'careerPoints': 100, 'gamesPlayed': 3},
      newGame: nearlyDeadGame,
    );
    expect(find.byType(GameOverScreen), findsNothing);
    await dragToCell(tester, 0, 0, 1);
    await tester.pumpAndSettle();

    expect(find.byType(GameOverScreen), findsOneWidget);
    expect(find.text('CHEQUERED FLAG'), findsOneWidget);
    expect(storage.gamesPlayed, 4);
    expect(storage.careerPoints, 101); // 1 point for the single
    expect(storage.bestScore, 50);

    // Rebuilds and extra frames never book it again.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: invalid_use_of_protected_member
    tester.state<State>(find.byType(GameScreen)).setState(() {});
    await tester.pumpAndSettle();
    expect(storage.gamesPlayed, 4);
    expect(storage.careerPoints, 101);
  });

  testWidgets('NEW RACE starts a fresh run that books once more', (
    tester,
  ) async {
    final storage = await pumpScreen(
      tester,
      const Size(375, 667),
      newGame: nearlyDeadGame,
    );
    await dragToCell(tester, 0, 0, 1);
    await tester.pumpAndSettle();
    expect(find.text('NEW POLE!'), findsOneWidget);
    expect(storage.bestScore, 1);

    await tester.tap(find.text('NEW RACE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameOverScreen), findsNothing);
    expect(scoreOf(tester), '0');

    await dragToCell(tester, 0, 0, 3);
    await tester.pumpAndSettle();
    expect(find.byType(GameOverScreen), findsOneWidget);
    expect(storage.gamesPlayed, 2);
    expect(storage.careerPoints, 2);
  });

  testWidgets('GARAGE on the flag screen returns to the previous route', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    GameScreen(storage: storage, newGame: nearlyDeadGame),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await dragToCell(tester, 0, 0, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
