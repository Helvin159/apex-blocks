import 'piece.dart';

/// Board side length.
const int boardSize = 8;

/// The rows and columns removed by one clear.
typedef ClearedLines = ({List<int> rows, List<int> cols});

/// An 8×8 grid of nullable colorIds (null = empty).
class Board {
  final List<List<int?>> _grid;

  Board()
    : _grid = List.generate(boardSize, (_) => List.filled(boardSize, null));

  Board._(this._grid);

  Board copy() => Board._([for (final row in _grid) List<int?>.of(row)]);

  int? cellAt(int row, int col) => _grid[row][col];

  bool _inBounds(int row, int col) =>
      row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  /// Fills a single cell directly. Intended for setting up boards.
  void setCell(int row, int col, int? colorId) => _grid[row][col] = colorId;

  bool canPlace(Piece piece, int row, int col) {
    for (final cell in piece.cells) {
      final r = row + cell.row;
      final c = col + cell.col;
      if (!_inBounds(r, c) || _grid[r][c] != null) return false;
    }
    return true;
  }

  /// Stamps the piece onto the board. Throws if it does not fit.
  void place(Piece piece, int row, int col) {
    if (!canPlace(piece, row, col)) {
      throw ArgumentError('${piece.id} does not fit at ($row, $col)');
    }
    for (final cell in piece.cells) {
      _grid[row + cell.row][col + cell.col] = piece.colorId;
    }
  }

  List<int> fullRows() => [
    for (var r = 0; r < boardSize; r++)
      if (_grid[r].every((v) => v != null)) r,
  ];

  List<int> fullCols() => [
    for (var c = 0; c < boardSize; c++)
      if (List.generate(boardSize, (r) => _grid[r][c]).every((v) => v != null))
        c,
  ];

  /// Finds all full rows and columns first, then clears them together so a
  /// shared cell is cleared once.
  ClearedLines clearLines() {
    final rows = fullRows();
    final cols = fullCols();
    for (final r in rows) {
      for (var c = 0; c < boardSize; c++) {
        _grid[r][c] = null;
      }
    }
    for (final c in cols) {
      for (var r = 0; r < boardSize; r++) {
        _grid[r][c] = null;
      }
    }
    return (rows: rows, cols: cols);
  }

  bool anyPlacementFor(Piece piece) {
    for (var r = 0; r <= boardSize - piece.height; r++) {
      for (var c = 0; c <= boardSize - piece.width; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  int get emptyCount =>
      _grid.fold(0, (sum, row) => sum + row.where((v) => v == null).length);
}
