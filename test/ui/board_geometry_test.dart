import 'package:flutter_test/flutter_test.dart';

import 'package:apexblocks/ui/board_geometry.dart';

/// Pointer position (panel coordinates) that puts a [rows]×[cols] piece's
/// top-left exactly on cell ([row], [col]) for the given lift.
Offset pointerFor(
  BoardGeometry g,
  int row,
  int col,
  int rows,
  int cols, {
  double lift = dragLiftCells,
}) {
  final topLeft = g.cellRect(row, col).topLeft;
  return Offset(
    topLeft.dx + (cols * g.step - cellGap) / 2,
    topLeft.dy + (rows * g.step - cellGap) / 2 + lift * g.step,
  );
}

void main() {
  group('cell rects', () {
    for (final width in [336.0, 288.0]) {
      test('panel width $width', () {
        final g = BoardGeometry(width);
        final cell = (width - 2 * boardPadding - 7 * cellGap) / 8;
        expect(g.cellSize, closeTo(cell, 1e-9));
        expect(g.step, closeTo(cell + cellGap, 1e-9));
        expect(g.panelHeight, width + stripHeight);

        final first = g.cellRect(0, 0);
        expect(first.left, boardPadding);
        expect(first.top, stripHeight + boardPadding);
        expect(first.width, closeTo(cell, 1e-9));
        expect(first.height, closeTo(cell, 1e-9));

        final last = g.cellRect(7, 7);
        expect(last.right, closeTo(width - boardPadding, 1e-9));
        expect(last.bottom, closeTo(g.panelHeight - boardPadding, 1e-9));

        // Neighbours are exactly one gap apart.
        expect(
          g.cellRect(3, 4).left - g.cellRect(3, 3).right,
          closeTo(cellGap, 1e-9),
        );
        expect(
          g.cellRect(4, 3).top - g.cellRect(3, 3).bottom,
          closeTo(cellGap, 1e-9),
        );
      });
    }

    test('row and column rects span the grid', () {
      final g = BoardGeometry(336);
      final row = g.rowRect(2);
      expect(row.left, g.cellRect(2, 0).left);
      expect(row.right, g.cellRect(2, 7).right);
      expect(row.height, closeTo(g.cellSize, 1e-9));
      final col = g.colRect(5);
      expect(col.top, g.cellRect(0, 5).top);
      expect(col.bottom, g.cellRect(7, 5).bottom);
    });
  });

  group('targetCell', () {
    for (final width in [336.0, 288.0]) {
      final g = BoardGeometry(width);

      test('corners with a 1x1 piece at width $width', () {
        for (final (r, c) in [(0, 0), (0, 7), (7, 0), (7, 7)]) {
          expect(targetCell(g, pointerFor(g, r, c, 1, 1), 1, 1), (
            row: r,
            col: c,
          ));
        }
      });

      test('corners with a 3x3 piece at width $width', () {
        for (final (r, c) in [(0, 0), (0, 5), (5, 0), (5, 5)]) {
          expect(targetCell(g, pointerFor(g, r, c, 3, 3), 3, 3), (
            row: r,
            col: c,
          ));
        }
      });
    }

    test('wide piece: last valid column vs one past it', () {
      final g = BoardGeometry(336);
      expect(targetCell(g, pointerFor(g, 2, 3, 1, 5), 1, 5), (row: 2, col: 3));
      final past = pointerFor(g, 2, 4, 1, 5);
      expect(targetCell(g, past, 1, 5), isNull);
    });

    test('tall piece: last valid row vs one past it', () {
      final g = BoardGeometry(288);
      expect(targetCell(g, pointerFor(g, 3, 6, 5, 1), 5, 1), (row: 3, col: 6));
      expect(targetCell(g, pointerFor(g, 4, 6, 5, 1), 5, 1), isNull);
    });

    test('snaps within half a cell of the edge, null beyond', () {
      final g = BoardGeometry(336);
      Offset shift(Offset p, double dx, double dy) =>
          p + Offset(dx * g.step, dy * g.step);

      final topLeft = pointerFor(g, 0, 0, 2, 2);
      expect(targetCell(g, shift(topLeft, -0.4, 0), 2, 2), (row: 0, col: 0));
      expect(targetCell(g, shift(topLeft, -0.6, 0), 2, 2), isNull);
      expect(targetCell(g, shift(topLeft, 0, -0.4), 2, 2), (row: 0, col: 0));
      expect(targetCell(g, shift(topLeft, 0, -0.6), 2, 2), isNull);

      final bottomRight = pointerFor(g, 6, 6, 2, 2);
      expect(targetCell(g, shift(bottomRight, 0.4, 0.4), 2, 2), (
        row: 6,
        col: 6,
      ));
      expect(targetCell(g, shift(bottomRight, 0.6, 0), 2, 2), isNull);
      expect(targetCell(g, shift(bottomRight, 0, 0.6), 2, 2), isNull);
    });

    test('far off-board and above the board are null', () {
      final g = BoardGeometry(336);
      expect(targetCell(g, const Offset(-200, 100), 1, 1), isNull);
      expect(targetCell(g, const Offset(168, -200), 1, 1), isNull);
      expect(targetCell(g, const Offset(168, 900), 1, 1), isNull);
    });

    test('lift moves the target up by dragLiftCells', () {
      final g = BoardGeometry(336);
      // Pointer directly under the center of cell (5, 3).
      final pointer = g.cellRect(5, 3).center;
      expect(targetCell(g, pointer, 1, 1, liftCells: 0), (row: 5, col: 3));
      // The piece center floats 1.5 steps higher, so its top-left row is 3.5,
      // which rounds to 4.
      expect(targetCell(g, pointer, 1, 1), (row: 4, col: 3));
      expect(dragLiftCells, 1.5);
      // Exactly two cells of lift is a clean two-row shift.
      expect(targetCell(g, pointer, 1, 1, liftCells: 2), (row: 3, col: 3));
    });

    test('piece is centered horizontally on the pointer', () {
      final g = BoardGeometry(336);
      final pointer = pointerFor(g, 4, 2, 1, 4);
      expect(targetCell(g, pointer, 1, 4), (row: 4, col: 2));
      expect(pieceTopLeft(g, pointer, 1, 4).dx, g.cellRect(4, 2).left);
    });
  });
}
