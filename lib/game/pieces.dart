import 'dart:math';

import 'piece.dart';

/// Number of distinct piece colors (colorId runs 0 to this minus one).
const int colorCount = 6;

/// Fixed color id per family, matching the block palette order:
///   0 red    — single, lTetromino, square3
///   1 yellow — domino, tTetromino
///   2 white  — lineTromino, sTetromino
///   3 teal   — lTromino, linePentomino
///   4 green  — square2
///   5 purple — lineTetromino
const Map<PieceFamily, int> familyColorIds = {
  PieceFamily.single: 0,
  PieceFamily.domino: 1,
  PieceFamily.lineTromino: 2,
  PieceFamily.lTromino: 3,
  PieceFamily.square2: 4,
  PieceFamily.lineTetromino: 5,
  PieceFamily.lTetromino: 0,
  PieceFamily.tTetromino: 1,
  PieceFamily.sTetromino: 2,
  PieceFamily.linePentomino: 3,
  PieceFamily.square3: 0,
};

// Spawn weights per family. A family's weight is split evenly across its
// orientations, so adding orientations never changes how often it appears.
const double weightSingle = 4;
const double weightDomino = 8;
const double weightLineTromino = 8;
const double weightLTromino = 8;
const double weightSquare2 = 8;
const double weightLineTetromino = 6;
const double weightLTetromino = 8;
const double weightTTetromino = 6;
const double weightSTetromino = 6;
const double weightLinePentomino = 3;
const double weightSquare3 = 2;

const Map<PieceFamily, double> familyWeights = {
  PieceFamily.single: weightSingle,
  PieceFamily.domino: weightDomino,
  PieceFamily.lineTromino: weightLineTromino,
  PieceFamily.lTromino: weightLTromino,
  PieceFamily.square2: weightSquare2,
  PieceFamily.lineTetromino: weightLineTetromino,
  PieceFamily.lTetromino: weightLTetromino,
  PieceFamily.tTetromino: weightTTetromino,
  PieceFamily.sTetromino: weightSTetromino,
  PieceFamily.linePentomino: weightLinePentomino,
  PieceFamily.square3: weightSquare3,
};

class _FamilySpec {
  final PieceFamily family;
  final List<Cell> base;

  /// Whether mirror images count as extra orientations.
  final bool mirror;
  const _FamilySpec(this.family, this.base, {this.mirror = false});
}

Cell _c(int row, int col) => (row: row, col: col);

final List<_FamilySpec> _specs = [
  _FamilySpec(PieceFamily.single, [_c(0, 0)]),
  _FamilySpec(PieceFamily.domino, [_c(0, 0), _c(0, 1)]),
  _FamilySpec(PieceFamily.lineTromino, [_c(0, 0), _c(0, 1), _c(0, 2)]),
  _FamilySpec(PieceFamily.lTromino, [_c(0, 0), _c(1, 0), _c(1, 1)]),
  _FamilySpec(PieceFamily.square2, [_c(0, 0), _c(0, 1), _c(1, 0), _c(1, 1)]),
  _FamilySpec(PieceFamily.lineTetromino, [
    _c(0, 0),
    _c(0, 1),
    _c(0, 2),
    _c(0, 3),
  ]),
  _FamilySpec(PieceFamily.lTetromino, [
    _c(0, 0),
    _c(1, 0),
    _c(2, 0),
    _c(2, 1),
  ], mirror: true),
  _FamilySpec(PieceFamily.tTetromino, [_c(0, 0), _c(0, 1), _c(0, 2), _c(1, 1)]),
  _FamilySpec(PieceFamily.sTetromino, [
    _c(0, 1),
    _c(0, 2),
    _c(1, 0),
    _c(1, 1),
  ], mirror: true),
  _FamilySpec(PieceFamily.linePentomino, [
    _c(0, 0),
    _c(0, 1),
    _c(0, 2),
    _c(0, 3),
    _c(0, 4),
  ]),
  _FamilySpec(PieceFamily.square3, [
    for (var r = 0; r < 3; r++)
      for (var c = 0; c < 3; c++) _c(r, c),
  ]),
];

List<Cell> _normalize(List<Cell> cells) {
  final minRow = cells.map((c) => c.row).reduce(min);
  final minCol = cells.map((c) => c.col).reduce(min);
  final out = [for (final c in cells) _c(c.row - minRow, c.col - minCol)];
  out.sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
  return out;
}

List<Cell> _rotate(List<Cell> cells) => [
  for (final c in cells) _c(c.col, -c.row),
];

List<Cell> _mirror(List<Cell> cells) => [
  for (final c in cells) _c(c.row, -c.col),
];

String _key(List<Cell> cells) =>
    cells.map((c) => '${c.row},${c.col}').join(';');

List<Piece> _buildFamily(_FamilySpec spec) {
  final seen = <String>{};
  final shapes = <List<Cell>>[];
  for (final start in [spec.base, if (spec.mirror) _mirror(spec.base)]) {
    var current = start;
    for (var i = 0; i < 4; i++) {
      final normalized = _normalize(current);
      if (seen.add(_key(normalized))) shapes.add(normalized);
      current = _rotate(current);
    }
  }
  final colorId = familyColorIds[spec.family]!;
  return [
    for (var i = 0; i < shapes.length; i++)
      Piece(
        id: '${spec.family.name}_$i',
        family: spec.family,
        cells: shapes[i],
        colorId: colorId,
      ),
  ];
}

/// Every orientation of every family, grouped by family.
final Map<PieceFamily, List<Piece>> piecesByFamily = {
  for (final spec in _specs) spec.family: _buildFamily(spec),
};

/// Flat list of every piece orientation.
final List<Piece> allPieces = List.unmodifiable(
  piecesByFamily.values.expand((p) => p),
);

/// Spawn weight of one orientation: the family weight split evenly.
double orientationWeight(Piece piece) =>
    familyWeights[piece.family]! / piecesByFamily[piece.family]!.length;

/// The single-cell piece, used as the dealer's last-resort fallback.
final Piece singlePiece = piecesByFamily[PieceFamily.single]!.first;

/// Picks one piece by spawn weight.
Piece pickPiece(Random random) {
  final total = allPieces.fold<double>(
    0,
    (sum, p) => sum + orientationWeight(p),
  );
  var roll = random.nextDouble() * total;
  for (final piece in allPieces) {
    roll -= orientationWeight(piece);
    if (roll < 0) return piece;
  }
  return allPieces.last;
}
