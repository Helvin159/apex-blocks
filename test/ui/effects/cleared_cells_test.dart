import 'package:apexblocks/game/board.dart';
import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/ui/effects/cleared_cells.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_support.dart';

void main() {
  final single = family(PieceFamily.single);

  test(
    'a cleared row keeps its colors; the placed cell takes the piece color',
    () {
      final before = Board();
      for (var c = 0; c < boardSize - 1; c++) {
        before.setCell(3, c, 2);
      }
      final cells = clearedCellsOf(
        before: before,
        piece: single,
        row: 3,
        col: 7,
        clearedRows: [3],
        clearedCols: [],
      );
      expect(cells.length, boardSize);
      expect(cells.every((c) => c.row == 3), isTrue);
      expect(cells.firstWhere((c) => c.col == 0).colorId, 2);
      expect(cells.firstWhere((c) => c.col == 7).colorId, single.colorId);
    },
  );

  test('a cell shared by a cleared row and column appears once', () {
    final before = Board();
    for (var c = 0; c < boardSize; c++) {
      before.setCell(3, c, 2);
    }
    for (var r = 0; r < boardSize; r++) {
      before.setCell(r, 7, 4);
    }
    before.setCell(3, 7, null);
    final cells = clearedCellsOf(
      before: before,
      piece: single,
      row: 3,
      col: 7,
      clearedRows: [3],
      clearedCols: [7],
    );
    expect(cells.length, 2 * boardSize - 1);
    expect({for (final c in cells) (c.row, c.col)}.length, cells.length);
    expect(cells.firstWhere((c) => c.row == 3 && c.col == 0).colorId, 2);
    expect(cells.firstWhere((c) => c.row == 0 && c.col == 7).colorId, 4);
    expect(
      cells.firstWhere((c) => c.row == 3 && c.col == 7).colorId,
      single.colorId,
    );
  });

  test('no clear means no cells', () {
    expect(
      clearedCellsOf(
        before: Board(),
        piece: single,
        row: 0,
        col: 0,
        clearedRows: [],
        clearedCols: [],
      ),
      isEmpty,
    );
  });
}
