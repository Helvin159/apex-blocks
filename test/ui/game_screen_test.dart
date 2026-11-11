import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexblocks/ui/board_geometry.dart';
import 'package:apexblocks/ui/board_view.dart';
import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/services/storage_service.dart';
import 'package:apexblocks/ui/game_over_screen.dart';
import 'package:apexblocks/ui/effects/clear_effects.dart';
import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/ui/tray_view.dart';

import 'test_support.dart';

Future<StorageService> pumpScreen(
  WidgetTester tester,
  Size size, {
  Map<String, Object> prefs = const {},
  GameState Function()? newGame,
  RecordingAudio? audio,
  RecordingHaptics? haptics,
}) async {
  useScreen(tester, size);
  final storage = await makeStorage(prefs);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        storage: storage,
        newGame: newGame ?? GameState.new,
        audio: audio,
        haptics: haptics,
      ),
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

/// Drags tray slot [slot] to board cell ([row], [col]) and releases. For a
/// multi-cell piece pass the middle of its footprint (e.g. 0.5, 0.5 for a
/// 2×2 whose top-left cell is (0, 0)). With [settle] false it pumps only one
/// frame after release, so effects that start on the drop are still running.
Future<void> dragToCell(
  WidgetTester tester,
  int slot,
  num row,
  num col, {
  bool settle = true,
}) async {
  final board = tester.widget<BoardView>(find.byType(BoardView));
  final geometry = board.geometry;
  final target =
      tester.getTopLeft(find.byType(BoardView)) +
      geometry.cellRect(0, 0).center +
      Offset(col * geometry.step, row * geometry.step) +
      Offset(0, dragLiftCells * geometry.step);
  final start = tester.getCenter(slots.at(slot));
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo((start + target) / 2);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 200));
  await gesture.up();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

ClearEffectsController effectsOf(WidgetTester tester) => tester
    .widget<ClearEffectsOverlay>(find.byType(ClearEffectsOverlay))
    .controller;

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

  testWidgets('sounds and haptics follow placements and clears', (
    tester,
  ) async {
    final audio = RecordingAudio();
    final haptics = RecordingHaptics();
    await pumpScreen(
      tester,
      const Size(375, 667),
      newGame: oneLineFromClearing,
      audio: audio,
      haptics: haptics,
    );
    await dragToCell(tester, 1, 0.5, 0.5); // a 2×2 square: no clear
    expect(audio.events, ['place']);
    expect(haptics.placements, [(lines: 0, combo: 0)]);

    await dragToCell(tester, 0, 7, 7); // the single completes row 7
    expect(audio.events, ['place', 'place', 'clear_1']);
    expect(haptics.placements.last, (lines: 1, combo: 1));
  });

  testWidgets('a clear plays an overlay that never blocks the next drag', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const Size(375, 667),
      newGame: oneLineFromClearing,
    );
    final effects = effectsOf(tester);
    expect(effects.isActive, isFalse);

    await dragToCell(tester, 0, 7, 7, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(effects.isActive, isTrue);
    expect(effects.particles.activeCount, greaterThan(0));
    final scoreAfterClear = scoreOf(tester);

    // Mid-effect, the next drag works at once.
    await dragToCell(tester, 1, 0.5, 0.5, settle: false);
    expect(effects.isActive, isTrue);
    expect(int.parse(scoreOf(tester)), greaterThan(int.parse(scoreAfterClear)));

    // And the overlay finishes on its own and stops its ticker.
    await tester.pumpAndSettle();
    expect(effects.isActive, isFalse);
    expect(effects.particles.activeCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips particles and keeps a simple fade', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScreen(
      tester,
      const Size(375, 667),
      newGame: oneLineFromClearing,
    );
    final effects = effectsOf(tester);

    await dragToCell(tester, 0, 7, 7, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(effects.isActive, isTrue); // the fade is running
    expect(effects.particles.activeCount, 0);

    await tester.pumpAndSettle(); // the fade ends on its own
    expect(effects.isActive, isFalse);
  });

  testWidgets('restart clears a running effect', (tester) async {
    await pumpScreen(
      tester,
      const Size(375, 667),
      newGame: oneLineFromClearing,
    );
    final effects = effectsOf(tester);
    await dragToCell(tester, 0, 7, 7, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(effects.isActive, isTrue);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESTART'));
    await tester.pumpAndSettle();
    expect(effects.isActive, isFalse);
  });
}
