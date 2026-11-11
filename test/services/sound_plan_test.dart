import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/services/sound_plan.dart';
import 'package:flutter_test/flutter_test.dart';

PlacementResult result({int rows = 0, int cols = 0, int combo = 0}) =>
    PlacementResult(
      placedCells: const [],
      clearedRows: List.generate(rows, (i) => i),
      clearedCols: List.generate(cols, (i) => i),
      pointsGained: 0,
      comboAfter: combo,
      trayRefilled: false,
      gameOver: false,
    );

SoundPlan plan(
  PlacementResult r, {
  int score = 100,
  int pole = 0,
  bool passed = false,
  int? since,
}) => soundPlanFor(
  result: r,
  scoreAfter: score,
  poleBefore: pole,
  polePassedAlready: passed,
  msSinceLastPassby: since,
);

void main() {
  test('no clear: no chime, no pass-by', () {
    final p = plan(result());
    expect(p.chimeVariant, isNull);
    expect(p.passby, isFalse);
  });

  test('single clear: chime only', () {
    final p = plan(result(rows: 1, combo: 1));
    expect(p.chimeVariant, 1);
    expect(p.passby, isFalse);
  });

  test('combo clears climb the chime and stay without a pass-by', () {
    expect(plan(result(cols: 1, combo: 3)).chimeVariant, 3);
    expect(plan(result(cols: 2, combo: 9)).chimeVariant, 6);
    expect(plan(result(cols: 2, combo: 9)).passby, isFalse);
  });

  test('FASTEST LAP (3+ lines): chime and pass-by', () {
    final p = plan(result(rows: 2, cols: 1, combo: 1));
    expect(p.chimeVariant, 1);
    expect(p.passby, isTrue);
  });

  test('first Pole pass: pass-by, chime still plays on a clear', () {
    final p = plan(result(rows: 1, combo: 1), score: 501, pole: 500);
    expect(p.polePassed, isTrue);
    expect(p.passby, isTrue);
    expect(p.chimeVariant, 1);
  });

  test('Pole pass without a clear still gets the pass-by', () {
    final p = plan(result(), score: 501, pole: 500);
    expect(p.passby, isTrue);
    expect(p.chimeVariant, isNull);
  });

  test('Pole of 0: passing it gives no pass-by', () {
    final p = plan(result(rows: 1, combo: 1), score: 50, pole: 0);
    expect(p.polePassed, isFalse);
    expect(p.passby, isFalse);
  });

  test('a Pole already passed this run does not fire again', () {
    final p = plan(result(), score: 900, pole: 500, passed: true);
    expect(p.polePassed, isFalse);
    expect(p.passby, isFalse);
  });

  test('cooldown blocks a second pass-by, then expires', () {
    final big = result(rows: 3, combo: 1);
    expect(plan(big, since: passbyCooldownMs - 1).passby, isFalse);
    expect(plan(big, since: passbyCooldownMs).passby, isTrue);
  });

  test('a blocked Pole pass is still marked as passed', () {
    final p = plan(result(), score: 501, pole: 500, since: 100);
    expect(p.passby, isFalse);
    expect(p.polePassed, isTrue);
  });

  test('Pole pass plus FASTEST LAP on one move is a single pass-by', () {
    final p = plan(result(rows: 3, combo: 1), score: 900, pole: 500);
    expect(p.passby, isTrue);
    expect(p.polePassed, isTrue);
  });
}
