import 'dart:math';

import 'package:apexblocks/game/board.dart';
import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/game/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

Piece fam(PieceFamily f, [int i = 0]) => piecesByFamily[f]![i];

List<String> ids(Iterable<Piece?> tray) => [for (final p in tray) p!.id];

/// Fills row [r] except the given columns.
void fillRow(Board b, int r, {List<int> skip = const []}) {
  for (var c = 0; c < boardSize; c++) {
    if (!skip.contains(c)) b.setCell(r, c, 1);
  }
}

/// A board where only the cells in [open] are empty.
Board boardWithOnly(List<Cell> open) {
  final b = Board();
  for (var r = 0; r < boardSize; r++) {
    for (var c = 0; c < boardSize; c++) {
      if (!open.contains((row: r, col: c))) b.setCell(r, c, 1);
    }
  }
  return b;
}

void main() {
  final single = fam(PieceFamily.single);
  final domino = fam(PieceFamily.domino); // horizontal 1×2

  test('starts with a full tray, zeroed stats', () {
    final g = GameState(random: Random(1));
    expect(g.tray.whereType<Piece>().length, traySize);
    expect(
      [g.score, g.combo, g.linesCleared, g.bestCombo, g.piecesPlaced],
      [0, 0, 0, 0, 0],
    );
  });

  test('place scores cells, clears a row, and updates stats', () {
    final b = Board();
    fillRow(b, 0, skip: [7]);
    final g = GameState(board: b, tray: [single, single, single]);
    final r = g.place(0, 0, 7);
    expect(r.clearedRows, [0]);
    expect(r.pointsGained, 1 + 10);
    expect(r.comboAfter, 1);
    expect(g.score, 11);
    expect(g.linesCleared, 1);
    expect(g.piecesPlaced, 1);
    expect(g.tray[0], isNull);
  });

  test('combo climbs ×1.0 → ×1.5 → ×2.0 and resets on a non-clearing move', () {
    final b = Board();
    for (final r in [0, 2, 4]) {
      fillRow(b, r, skip: [0]);
    }
    final g = GameState(board: b, tray: [single, single, single]);
    expect(g.place(0, 0, 0).pointsGained, 1 + 10);
    // Reload the tray so we can keep placing.
    g.tray.setAll(0, [single, single, single]);
    expect(g.place(0, 2, 0).pointsGained, 1 + 15);
    g.tray.setAll(0, [single, single, single]);
    expect(g.place(0, 4, 0).pointsGained, 1 + 20);
    expect(g.combo, 3);
    expect(g.bestCombo, 3);
    g.tray.setAll(0, [single, single, single]);
    final miss = g.place(0, 6, 0);
    expect(miss.pointsGained, 1);
    expect(miss.comboAfter, 0);
    expect(g.bestCombo, 3);
  });

  test('worked example from the spec totals 23', () {
    final b = Board();
    fillRow(b, 0, skip: [0, 1, 2]);
    final g = GameState(
      board: b,
      tray: [fam(PieceFamily.lineTromino), single, single],
    );
    g.combo = 2; // third consecutive clear
    final r = g.place(0, 0, 0);
    expect(r.pointsGained, 23);
  });

  test('row + column clear counts as 2 lines', () {
    final b = Board();
    fillRow(b, 3, skip: [3]);
    for (var r = 0; r < boardSize; r++) {
      if (r != 3) b.setCell(r, 3, 1);
    }
    final g = GameState(board: b, tray: [single, single, single]);
    final r = g.place(0, 3, 3);
    expect(r.clearedRows, [3]);
    expect(r.clearedCols, [3]);
    expect(r.pointsGained, 1 + 40);
  });

  test('tray refills only after all 3 pieces are placed', () {
    final g = GameState(
      random: Random(3),
      board: Board(),
      tray: [single, single, single],
    );
    expect(g.place(0, 0, 0).trayRefilled, isFalse);
    expect(g.tray.whereType<Piece>().length, 2);
    expect(g.place(1, 1, 1).trayRefilled, isFalse);
    expect(g.tray.whereType<Piece>().length, 1);
    final last = g.place(2, 2, 2);
    expect(last.trayRefilled, isTrue);
    expect(g.tray.whereType<Piece>().length, traySize);
  });

  test('invalid placement and empty slot throw', () {
    final g = GameState(tray: [single, null, single]);
    expect(() => g.place(0, -1, 0), throwsArgumentError);
    expect(() => g.place(1, 0, 0), throwsStateError);
  });

  group('game over', () {
    test('detected on a near-full board', () {
      final b = boardWithOnly([(row: 0, col: 0)]);
      final g = GameState(board: b, tray: [domino, domino, domino]);
      expect(g.isGameOver, isTrue);
    });

    test('not triggered while any piece fits', () {
      final b = boardWithOnly([(row: 0, col: 0)]);
      final g = GameState(board: b, tray: [domino, single, domino]);
      expect(g.isGameOver, isFalse);
    });

    test('place reports gameOver in its result', () {
      // Checkerboard: no full lines and no two adjacent holes, so only a
      // single can ever be placed.
      final b = Board();
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if ((r + c).isEven) b.setCell(r, c, 1);
        }
      }
      final g = GameState(board: b, tray: [single, domino, domino]);
      expect(g.isGameOver, isFalse);
      expect(g.place(0, 0, 1).gameOver, isTrue);
    });
  });

  group('fair dealer', () {
    test('never deals a 3×3 when no 3×3 gap exists', () {
      // Every 3×3 window contains one cell with row % 3 == 2 and col % 3 == 2.
      final b = Board();
      for (var r = 2; r < boardSize; r += 3) {
        for (var c = 2; c < boardSize; c += 3) {
          b.setCell(r, c, 1);
        }
      }
      expect(b.anyPlacementFor(fam(PieceFamily.square3)), isFalse);
      for (var seed = 0; seed < 500; seed++) {
        final g = GameState(
          random: Random(seed),
          board: b,
          tray: [single, single, single],
        );
        for (final p in g.dealTray()) {
          expect(p.family, isNot(PieceFamily.square3));
        }
      }
    });

    test('every piece fits across 1,000 deals on random boards', () {
      for (var seed = 0; seed < 1000; seed++) {
        final rng = Random(seed);
        final density = 0.2 + rng.nextDouble() * 0.7;
        final b = Board();
        for (var r = 0; r < boardSize; r++) {
          for (var c = 0; c < boardSize; c++) {
            if (rng.nextDouble() < density) b.setCell(r, c, 1);
          }
        }
        b.setCell(rng.nextInt(boardSize), rng.nextInt(boardSize), null);
        final g = GameState(
          random: rng,
          board: b,
          tray: [single, single, single],
        )..score = rng.nextInt(2000);
        final dealt = g.dealTray();
        expect(dealt.length, traySize);
        for (final p in dealt) {
          expect(b.anyPlacementFor(p), isTrue, reason: '${p.id} (seed $seed)');
        }
      }
    });

    test('only singles are dealt when only 1×1 gaps exist', () {
      final b = Board();
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if ((r + c).isEven) b.setCell(r, c, 1);
        }
      }
      for (var seed = 0; seed < 100; seed++) {
        final g = GameState(
          random: Random(seed),
          board: b,
          tray: [single, single, single],
        );
        for (final p in g.dealTray()) {
          expect(p.family, PieceFamily.single);
        }
      }
    });

    test('singles are not a rescue: on an open board they follow weight', () {
      final g = GameState(
        random: Random(11),
        board: Board(),
        tray: [single, single, single],
      );
      var singles = 0, total = 0;
      for (var i = 0; i < 2000; i++) {
        for (final p in g.dealTray()) {
          total++;
          if (p.family == PieceFamily.single) singles++;
        }
      }
      final expected =
          easyWeights[PieceFamily.single]! /
          easyWeights.values.fold<double>(0, (a, b) => a + b);
      expect(singles / total, closeTo(expected, 0.02));
    });

    test('a single is rarer than larger pieces when both fit', () {
      // Most of the board is full, but a 2×2 gap and a 1×1 gap both exist.
      final b = boardWithOnly([
        (row: 0, col: 0),
        (row: 0, col: 1),
        (row: 1, col: 0),
        (row: 1, col: 1),
        (row: 7, col: 7),
      ]);
      final g = GameState(
        random: Random(3),
        board: b,
        tray: [single, single, single],
      );
      var singles = 0, larger = 0;
      for (var i = 0; i < 1000; i++) {
        for (final p in g.dealTray()) {
          p.family == PieceFamily.single ? singles++ : larger++;
        }
      }
      expect(larger, greaterThan(singles));
    });

    test('still deals when nothing can fit', () {
      final g = GameState(
        random: Random(5),
        board: boardWithOnly([]),
        tray: [single, single, single],
      );
      final dealt = g.dealTray();
      expect(dealt.length, traySize);
    });
  });

  group('dealFittingTray', () {
    test('all 3 fit the board', () {
      final b = boardWithOnly([
        for (var c = 0; c < 4; c++) (row: 0, col: c),
        for (var c = 0; c < 4; c++) (row: 1, col: c),
      ]);
      for (var seed = 0; seed < 20; seed++) {
        final g = GameState(
          random: Random(seed),
          board: b,
          tray: [single, single, single],
        );
        for (final p in g.dealFittingTray()) {
          expect(b.anyPlacementFor(p), isTrue);
        }
      }
    });

    test('falls back to singles on a crowded board', () {
      final b = boardWithOnly([(row: 0, col: 0), (row: 7, col: 7)]);
      final g = GameState(
        random: Random(2),
        board: b,
        tray: [single, single, single],
      );
      final dealt = g.dealFittingTray();
      expect(dealt.length, traySize);
      for (final p in dealt) {
        expect(p.family, PieceFamily.single);
      }
    });
  });

  group('preview', () {
    test('matches what place does and mutates nothing', () {
      final b = Board();
      fillRow(b, 0, skip: [6, 7]);
      for (var r = 1; r < boardSize; r++) {
        b.setCell(r, 7, 1);
      }
      final g = GameState(board: b, tray: [domino, single, single]);
      final scoreBefore = g.score;
      final gridBefore = [
        for (var r = 0; r < boardSize; r++)
          [for (var c = 0; c < boardSize; c++) g.board.cellAt(r, c)],
      ];

      final p = g.preview(0, 0, 6);
      expect(p.valid, isTrue);
      expect(p.cells, [(row: 0, col: 6), (row: 0, col: 7)]);
      expect(p.wouldClearRows, [0]);
      expect(p.wouldClearCols, [7]);

      expect(g.score, scoreBefore);
      expect(g.tray[0], domino);
      expect([
        for (var r = 0; r < boardSize; r++)
          [for (var c = 0; c < boardSize; c++) g.board.cellAt(r, c)],
      ], gridBefore);

      final r = g.place(0, 0, 6);
      expect(r.clearedRows, p.wouldClearRows);
      expect(r.clearedCols, p.wouldClearCols);
      expect(r.placedCells, p.cells);
    });

    test('invalid positions and empty slots', () {
      final g = GameState(tray: [domino, null, single]);
      expect(g.preview(0, 0, 7).valid, isFalse);
      expect(g.preview(1, 0, 0).valid, isFalse);
    });
  });

  test('same seed gives the same sequence of trays', () {
    List<List<String>> run(int seed) {
      final g = GameState(random: Random(seed));
      final trays = [ids(g.tray)];
      for (var i = 0; i < 10; i++) {
        trays.add(ids(g.dealTray()));
      }
      return trays;
    }

    expect(run(42), run(42));
    expect(run(42), isNot(run(43)));
  });
}
