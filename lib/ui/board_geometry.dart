import 'dart:ui';

import '../game/board.dart';

/// Inner padding between the panel edge and the grid.
const double boardPadding = 8;

/// Gap between neighbouring cells.
const double cellGap = 4;

/// Height of the checkered strip along the top edge of the board panel.
const double stripHeight = 8;

/// How far a dragged piece floats above the finger, in board cells.
const double dragLiftCells = 1.5;

/// Where a dragged piece would land: its top-left cell.
typedef TargetCell = ({int row, int col});

/// Layout of the board panel for a given panel width. The panel is the
/// checkered strip on top of a square grid area.
class BoardGeometry {
  final double panelWidth;

  const BoardGeometry(this.panelWidth);

  double get cellSize =>
      (panelWidth - 2 * boardPadding - (boardSize - 1) * cellGap) / boardSize;

  /// Distance between the same edge of two neighbouring cells.
  double get step => cellSize + cellGap;

  double get panelHeight => panelWidth + stripHeight;

  Size get panelSize => Size(panelWidth, panelHeight);

  /// Top-left of cell (0, 0) in panel coordinates.
  Offset get gridOrigin =>
      const Offset(boardPadding, stripHeight + boardPadding);

  Rect cellRect(int row, int col) => Rect.fromLTWH(
    gridOrigin.dx + col * step,
    gridOrigin.dy + row * step,
    cellSize,
    cellSize,
  );

  /// The full-width band of a row, including its cell gaps' outer edges.
  Rect rowRect(int row) =>
      cellRect(row, 0).expandToInclude(cellRect(row, boardSize - 1));

  Rect colRect(int col) =>
      cellRect(0, col).expandToInclude(cellRect(boardSize - 1, col));
}

/// Top-left of a dragged piece's body in panel coordinates.
///
/// The piece's center sits [liftCells] above [pointer]; a piece that spans
/// [pieceRows] × [pieceCols] cells is centered on that point.
Offset pieceTopLeft(
  BoardGeometry geometry,
  Offset pointer,
  int pieceRows,
  int pieceCols, {
  double liftCells = dragLiftCells,
}) {
  final step = geometry.step;
  final center = Offset(pointer.dx, pointer.dy - liftCells * step);
  // Body extent excludes the trailing gap.
  return Offset(
    center.dx - (pieceCols * step - cellGap) / 2,
    center.dy - (pieceRows * step - cellGap) / 2,
  );
}

/// The top-left cell the piece snaps to, or null if it would hang more than
/// half a cell off the board (so the whole piece can't fit).
///
/// [pointer] is in panel coordinates (the board's local space).
TargetCell? targetCell(
  BoardGeometry geometry,
  Offset pointer,
  int pieceRows,
  int pieceCols, {
  double liftCells = dragLiftCells,
}) {
  final topLeft = pieceTopLeft(
    geometry,
    pointer,
    pieceRows,
    pieceCols,
    liftCells: liftCells,
  );
  final step = geometry.step;
  final origin = geometry.gridOrigin;
  final row = ((topLeft.dy - origin.dy) / step).round();
  final col = ((topLeft.dx - origin.dx) / step).round();
  if (row < 0 || col < 0) return null;
  if (row > boardSize - pieceRows || col > boardSize - pieceCols) return null;
  return (row: row, col: col);
}
