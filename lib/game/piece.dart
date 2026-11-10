/// A single cell offset, relative to a piece's top-left corner.
typedef Cell = ({int row, int col});

/// The shape families a piece can belong to. Each family spans one or more
/// orientations (distinct rotations and mirrors).
enum PieceFamily {
  single,
  domino,
  lineTromino,
  lTromino,
  square2,
  lineTetromino,
  lTetromino,
  tTetromino,
  sTetromino,
  linePentomino,
  square3,
}

/// An immutable piece orientation. Cells are normalized so the top-left of the
/// bounding box is (0, 0).
class Piece {
  /// Unique per family + orientation, e.g. `lTetromino_3`.
  final String id;
  final PieceFamily family;
  final List<Cell> cells;
  final int width;
  final int height;

  /// Palette index, 0–5.
  final int colorId;

  Piece({
    required this.id,
    required this.family,
    required List<Cell> cells,
    required this.colorId,
  }) : cells = List.unmodifiable(cells),
       width = cells.map((c) => c.col).reduce((a, b) => a > b ? a : b) + 1,
       height = cells.map((c) => c.row).reduce((a, b) => a > b ? a : b) + 1;

  @override
  bool operator ==(Object other) => other is Piece && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Piece($id)';
}
