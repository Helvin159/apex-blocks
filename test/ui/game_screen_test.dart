import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apexblocks/ui/board_geometry.dart';
import 'package:apexblocks/ui/board_view.dart';
import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/ui/tray_view.dart';

Future<void> pumpScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: GameScreen()));
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

void main() {
  for (final size in const [Size(320, 568), Size(375, 667), Size(430, 932)]) {
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
    expect(find.text('0'), findsOneWidget);
    await dragToBoardCenter(tester, 0);
    expect(find.text('0'), findsNothing);
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
    expect(find.text('0'), findsOneWidget);

    // The slot is usable again: dropping it on the board now scores.
    await dragToBoardCenter(tester, 1);
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
