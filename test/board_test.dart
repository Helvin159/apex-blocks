import 'package:apexblocks/game/board.dart';
import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/game/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

Piece family(PieceFamily f, [int i = 0]) => piecesByFamily[f]![i];

void main() {
  late Board board;
  setUp(() => board = Board());

  group('placement', () {
    test('valid placement fills the cells', () {
      final p = family(PieceFamily.square2);
      expect(board.canPlace(p, 3, 3), isTrue);
      board.place(p, 3, 3);
      expect(board.cellAt(3, 3), p.colorId);
      expect(board.cellAt(4, 4), p.colorId);
      expect(board.cellAt(5, 5), isNull);
    });

    test('overlap is rejected', () {
      board.place(family(PieceFamily.single), 2, 2);
      expect(board.canPlace(family(PieceFamily.square2), 1, 1), isFalse);
      expect(
        () => board.place(family(PieceFamily.square2), 1, 1),
        throwsArgumentError,
      );
    });

    test('out of bounds is rejected on every edge', () {
      final p = family(PieceFamily.square2);
      expect(board.canPlace(p, -1, 0), isFalse); // top
      expect(board.canPlace(p, 0, -1), isFalse); // left
      expect(board.canPlace(p, boardSize - 1, 0), isFalse); // bottom
      expect(board.canPlace(p, 0, boardSize - 1), isFalse); // right
      expect(board.canPlace(p, boardSize - 2, boardSize - 2), isTrue);
    });

    test('anyPlacementFor', () {
      final big = family(PieceFamily.square3);
      expect(board.anyPlacementFor(big), isTrue);
      // A checkerboard leaves no room for anything bigger than a single.
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if ((r + c).isEven) board.setCell(r, c, 0);
        }
      }
      expect(board.anyPlacementFor(big), isFalse);
      expect(board.anyPlacementFor(family(PieceFamily.domino)), isFalse);
      expect(board.anyPlacementFor(family(PieceFamily.single)), isTrue);
    });

    test('copy is independent', () {
      final copy = board.copy();
      copy.place(family(PieceFamily.single), 0, 0);
      expect(board.cellAt(0, 0), isNull);
    });
  });

  group('clears', () {
    void fillRow(int r, {int skip = -1}) {
      for (var c = 0; c < boardSize; c++) {
        if (c != skip) board.setCell(r, c, 1);
      }
    }

    void fillCol(int c, {int skip = -1}) {
      for (var r = 0; r < boardSize; r++) {
        if (r != skip) board.setCell(r, c, 1);
      }
    }

    test('single row', () {
      fillRow(4, skip: 7);
      board.place(family(PieceFamily.single), 4, 7);
      final cleared = board.clearLines();
      expect(cleared.rows, [4]);
      expect(cleared.cols, isEmpty);
      for (var c = 0; c < boardSize; c++) {
        expect(board.cellAt(4, c), isNull);
      }
    });

    test('single column', () {
      fillCol(2, skip: 0);
      board.place(family(PieceFamily.single), 0, 2);
      final cleared = board.clearLines();
      expect(cleared.cols, [2]);
      expect(cleared.rows, isEmpty);
    });

    test('row and column together clear the shared cell once', () {
      fillRow(3, skip: 3);
      fillCol(3, skip: 3);
      board.place(family(PieceFamily.single), 3, 3);
      board.setCell(0, 0, 5); // bystander that must survive
      final cleared = board.clearLines();
      expect(cleared.rows, [3]);
      expect(cleared.cols, [3]);
      expect(board.cellAt(3, 3), isNull);
      expect(board.cellAt(0, 0), 5);
      expect(board.emptyCount, boardSize * boardSize - 1);
    });

    test('three or more lines clear simultaneously', () {
      for (final r in [1, 4, 6]) {
        fillRow(r);
      }
      fillCol(0);
      final cleared = board.clearLines();
      expect(cleared.rows, [1, 4, 6]);
      expect(cleared.cols, [0]);
      expect(board.emptyCount, boardSize * boardSize);
    });

    test('nothing clears on a partial board', () {
      fillRow(0, skip: 0);
      final cleared = board.clearLines();
      expect(cleared.rows, isEmpty);
      expect(cleared.cols, isEmpty);
    });
  });
}
