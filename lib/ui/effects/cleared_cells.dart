import '../../game/board.dart';
import '../../game/piece.dart';

/// A cell removed by a clear, with the color it had.
typedef ClearedCell = ({int row, int col, int colorId});

/// The cells removed by a placement, with their colors. [before] is a copy
/// of the board from before the piece was placed (the live board has already
/// lost these cells). A cell shared by a cleared row and column appears once.
List<ClearedCell> clearedCellsOf({
  required Board before,
  required Piece piece,
  required int row,
  required int col,
  required List<int> clearedRows,
  required List<int> clearedCols,
}) {
  final placed = {
    for (final c in piece.cells) (row: row + c.row, col: col + c.col),
  };
  final seen = <(int, int)>{};
  final cells = <ClearedCell>[];

  void add(int r, int c) {
    if (!seen.add((r, c))) return;
    final isPlaced = placed.contains((row: r, col: c));
    cells.add((
      row: r,
      col: c,
      colorId: isPlaced
          ? piece.colorId
          : (before.cellAt(r, c) ?? piece.colorId),
    ));
  }

  for (final r in clearedRows) {
    for (var c = 0; c < boardSize; c++) {
      add(r, c);
    }
  }
  for (final c in clearedCols) {
    for (var r = 0; r < boardSize; r++) {
      add(r, c);
    }
  }
  return cells;
}
