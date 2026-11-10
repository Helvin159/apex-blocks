import 'package:apexblocks/game/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('per-cell points', () {
    expect(placementPoints(1), pointsPerCell);
    expect(placementPoints(5), 5 * pointsPerCell);
  });

  test('line bonus is base × n²', () {
    expect(lineBonus(1), lineBonusBase);
    expect(lineBonus(2), lineBonusBase * 4);
    expect(lineBonus(3), lineBonusBase * 9);
  });

  test('combo multiplier sequence 1.0 → 1.5 → 2.0, then capped', () {
    expect(comboMultiplier(0), 1.0);
    expect(comboMultiplier(1), 1.5);
    expect(comboMultiplier(2), 2.0);
    expect(comboMultiplier(9), 2.0);
  });

  test('clearPoints applies the multiplier to the bonus', () {
    expect(clearPoints(0, 2), 0);
    expect(clearPoints(1, 0), 10);
    expect(clearPoints(1, 1), 15);
    expect(clearPoints(2, 2), 80);
  });

  test('worked example: 3-cell piece, 3rd consecutive 1-line clear = 23', () {
    expect(placementPoints(3) + clearPoints(1, 2), 23);
  });
}
