import 'dart:math';

import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/game/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expected = {
    PieceFamily.single: (cells: 1, orientations: 1),
    PieceFamily.domino: (cells: 2, orientations: 2),
    PieceFamily.lineTromino: (cells: 3, orientations: 2),
    PieceFamily.lTromino: (cells: 3, orientations: 4),
    PieceFamily.square2: (cells: 4, orientations: 1),
    PieceFamily.lineTetromino: (cells: 4, orientations: 2),
    PieceFamily.lTetromino: (cells: 4, orientations: 8),
    PieceFamily.tTetromino: (cells: 4, orientations: 4),
    PieceFamily.sTetromino: (cells: 4, orientations: 4),
    PieceFamily.linePentomino: (cells: 5, orientations: 2),
    PieceFamily.square3: (cells: 9, orientations: 1),
  };

  test('family list matches the spec exactly', () {
    expect(PieceFamily.values.length, 11);
    expect(piecesByFamily.keys.toSet(), PieceFamily.values.toSet());
  });

  test('every family has a fixed color id 0-5', () {
    expect(familyColorIds.keys.toSet(), PieceFamily.values.toSet());
    for (final p in allPieces) {
      expect(p.colorId, familyColorIds[p.family]);
      expect(p.colorId, inInclusiveRange(0, 5));
    }
  });

  test('every family is covered by the expectations', () {
    expect(expected.keys.toSet(), PieceFamily.values.toSet());
  });

  for (final entry in expected.entries) {
    test('${entry.key.name}: orientation and cell counts', () {
      final pieces = piecesByFamily[entry.key]!;
      expect(pieces.length, entry.value.orientations);
      for (final p in pieces) {
        expect(p.cells.length, entry.value.cells);
      }
    });
  }

  test('no duplicate orientations within a family', () {
    for (final pieces in piecesByFamily.values) {
      final shapes = pieces
          .map((p) => p.cells.map((c) => '${c.row},${c.col}').join(';'))
          .toSet();
      expect(shapes.length, pieces.length);
    }
  });

  test('ids are unique and cells are normalized to 0,0', () {
    expect(allPieces.map((p) => p.id).toSet().length, allPieces.length);
    for (final p in allPieces) {
      expect(p.cells.map((c) => c.row).reduce(min), 0);
      expect(p.cells.map((c) => c.col).reduce(min), 0);
      expect(p.colorId, inInclusiveRange(0, colorCount - 1));
    }
  });

  test("a family's total weight is independent of its orientation count", () {
    for (final family in PieceFamily.values) {
      final total = piecesByFamily[family]!.fold<double>(
        0,
        (sum, p) => sum + orientationWeight(p),
      );
      expect(total, closeTo(familyWeights[family]!, 1e-9));
    }
  });

  test('orientation weights are split evenly within a family', () {
    for (final pieces in piecesByFamily.values) {
      final weights = pieces.map(orientationWeight).toSet();
      expect(weights.length, 1);
    }
  });

  test('picker is deterministic for a seed and reaches every family', () {
    final a = Random(7), b = Random(7);
    expect(
      [for (var i = 0; i < 20; i++) pickPiece(a).id],
      [for (var i = 0; i < 20; i++) pickPiece(b).id],
    );

    final rng = Random(1);
    final seen = {for (var i = 0; i < 5000; i++) pickPiece(rng).family};
    expect(seen, PieceFamily.values.toSet());
  });

  group('weightsForScore', () {
    test('equals easy at or below the ramp start', () {
      expect(weightsForScore(0), easyWeights);
      expect(weightsForScore(rampStartScore), easyWeights);
    });

    test('equals hard at or above the ramp end', () {
      expect(weightsForScore(rampEndScore), hardWeights);
      expect(weightsForScore(99999), hardWeights);
    });

    test('is halfway at 900', () {
      final mid = weightsForScore(900);
      for (final f in PieceFamily.values) {
        expect(mid[f], closeTo((easyWeights[f]! + hardWeights[f]!) / 2, 1e-9));
      }
    });

    test('family weight is still split evenly across orientations', () {
      for (final score in [0, 450, 900, 1300, 2000]) {
        final weights = weightsForScore(score);
        for (final family in PieceFamily.values) {
          final pieces = piecesByFamily[family]!;
          final total = pieces.fold<double>(
            0,
            (sum, p) => sum + orientationWeight(p, weights),
          );
          expect(total, closeTo(weights[family]!, 1e-9));
          expect(
            pieces.map((p) => orientationWeight(p, weights)).toSet().length,
            1,
          );
        }
      }
    });
  });
}
