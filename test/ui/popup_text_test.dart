import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/ui/popup_text.dart';
import 'package:flutter_test/flutter_test.dart';

PlacementResult result({
  int rows = 0,
  int cols = 0,
  int combo = 0,
  int points = 0,
}) => PlacementResult(
  placedCells: const [],
  clearedRows: List.generate(rows, (i) => i),
  clearedCols: List.generate(cols, (i) => i),
  pointsGained: points,
  comboAfter: combo,
  trayRefilled: false,
  gameOver: false,
);

void main() {
  test('no lines cleared: no pop-up', () {
    expect(popupFor(result(combo: 0, points: 4)), isNull);
  });

  test('1 line, first clear: no word, just +N', () {
    final p = popupFor(result(rows: 1, combo: 1, points: 14))!;
    expect(p.headline, isNull);
    expect(p.detail, '+14');
  });

  test('1 line with combo 2: OVERTAKE with combo line', () {
    final p = popupFor(result(cols: 1, combo: 2, points: 18))!;
    expect(p.headline, 'OVERTAKE!');
    expect(p.detail, 'COMBO ×2 · +18');
  });

  test('1 line with a long combo keeps OVERTAKE', () {
    final p = popupFor(result(rows: 1, combo: 3, points: 180))!;
    expect(p.headline, 'OVERTAKE!');
    expect(p.detail, 'COMBO ×3 · +180');
  });

  test('2 lines (rows, columns or mixed): SLIPSTREAM', () {
    for (final r in [
      result(rows: 2, combo: 1, points: 45),
      result(cols: 2, combo: 1, points: 45),
      result(rows: 1, cols: 1, combo: 1, points: 45),
    ]) {
      final p = popupFor(r)!;
      expect(p.headline, 'SLIPSTREAM!');
      expect(p.detail, isNull);
    }
  });

  test('2 lines with combo 2 adds the combo line', () {
    final p = popupFor(result(rows: 2, combo: 2, points: 90))!;
    expect(p.headline, 'SLIPSTREAM!');
    expect(p.detail, 'COMBO ×2 · +90');
  });

  test('3 or more lines: FASTEST LAP', () {
    for (final lines in [3, 4, 6]) {
      final p = popupFor(result(rows: lines, combo: 1, points: 100))!;
      expect(p.headline, 'FASTEST LAP!');
      expect(p.detail, isNull);
    }
  });

  test('3 lines beats combo when picking the word', () {
    final p = popupFor(result(rows: 2, cols: 1, combo: 4, points: 400))!;
    expect(p.headline, 'FASTEST LAP!');
    expect(p.detail, 'COMBO ×4 · +400');
  });
}
