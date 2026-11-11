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
// Two tables: the dealer blends from easy to hard as the run's score climbs.

/// Weights at the start of a run (score <= [rampStartScore]).
const Map<PieceFamily, double> easyWeights = {
  PieceFamily.single: 6,
  PieceFamily.domino: 10,
  PieceFamily.lineTromino: 8,
  PieceFamily.lTromino: 8,
  PieceFamily.square2: 8,
  PieceFamily.lineTetromino: 6,
  PieceFamily.lTetromino: 6,
  PieceFamily.tTetromino: 4,
  PieceFamily.sTetromino: 4,
  PieceFamily.linePentomino: 3,
  PieceFamily.square3: 2,
};

/// Weights late in a run (score >= [rampEndScore]).
const Map<PieceFamily, double> hardWeights = {
  PieceFamily.single: 2,
  PieceFamily.domino: 6,
  PieceFamily.lineTromino: 6,
  PieceFamily.lTromino: 6,
  PieceFamily.square2: 8,
  PieceFamily.lineTetromino: 8,
  PieceFamily.lTetromino: 9,
  PieceFamily.tTetromino: 7,
  PieceFamily.sTetromino: 7,
  PieceFamily.linePentomino: 5,
  PieceFamily.square3: 5,
};

/// Score where the blend from easy to hard weights begins.
const int rampStartScore = 300;

/// Score where the weights are fully hard.
const int rampEndScore = 1500;

/// The default weight table (the easy one).
const Map<PieceFamily, double> familyWeights = easyWeights;

/// Linear blend from [easyWeights] to [hardWeights] between [rampStartScore]
/// and [rampEndScore], clamped at both ends.
Map<PieceFamily, double> weightsForScore(int score) {
  final t = ((score - rampStartScore) / (rampEndScore - rampStartScore)).clamp(
    0.0,
    1.0,
  );
  return {
    for (final f in PieceFamily.values)
      f: easyWeights[f]! + (hardWeights[f]! - easyWeights[f]!) * t,
  };
}

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
double orientationWeight(
  Piece piece, [
  Map<PieceFamily, double> weights = easyWeights,
]) => weights[piece.family]! / piecesByFamily[piece.family]!.length;

/// The single-cell piece, used by the rewarded-continue fallback.
final Piece singlePiece = piecesByFamily[PieceFamily.single]!.first;

/// Picks one piece by spawn weight, only from pieces accepted by [where]
/// (all pieces by default). Falls back to every piece if none is accepted.
Piece pickPiece(
  Random random, {
  Map<PieceFamily, double> weights = easyWeights,
  bool Function(Piece)? where,
}) {
  var pool = allPieces;
  if (where != null) {
    final filtered = allPieces.where(where).toList();
    if (filtered.isNotEmpty) pool = filtered;
  }
  final total = pool.fold<double>(
    0,
    (sum, p) => sum + orientationWeight(p, weights),
  );
  var roll = random.nextDouble() * total;
  for (final piece in pool) {
    roll -= orientationWeight(piece, weights);
    if (roll < 0) return piece;
  }
  return pool.last;
}
