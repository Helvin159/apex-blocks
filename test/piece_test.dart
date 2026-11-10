import 'package:apexblocks/game/piece.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('width and height come from the cells', () {
    final p = Piece(
      id: 't',
      family: PieceFamily.lTromino,
      cells: [(row: 0, col: 0), (row: 1, col: 0), (row: 1, col: 1)],
      colorId: 2,
    );
    expect(p.width, 2);
    expect(p.height, 2);
    expect(p.colorId, 2);
  });

  test('cells are immutable', () {
    final p = Piece(
      id: 't',
      family: PieceFamily.single,
      cells: [(row: 0, col: 0)],
      colorId: 0,
    );
    expect(() => p.cells.add((row: 1, col: 1)), throwsUnsupportedError);
  });

  test('equality is by id', () {
    Piece make(String id) => Piece(
      id: id,
      family: PieceFamily.single,
      cells: [(row: 0, col: 0)],
      colorId: 0,
    );
    expect(make('a'), make('a'));
    expect(make('a'), isNot(make('b')));
  });
}
