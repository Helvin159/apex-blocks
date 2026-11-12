import 'package:flutter_test/flutter_test.dart';

import 'package:apexblocks/game/board.dart';
import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/ui/effects/drop_effects.dart';

Cell cell(int r, int c) => (row: r, col: c);

DropFxPlan plan(
  int cells, {
  bool clears = false,
  bool reduced = false,
  DropFxToggles toggles = const DropFxToggles(),
}) => DropFxPlan.forDrop(
  cellCount: cells,
  clearsLines: clears,
  reducedMotion: reduced,
  toggles: toggles,
);

void main() {
  group('squash', () {
    test('starts big, dips under 1, overshoots, ends exactly at rest', () {
      expect(DropFxMath.squashScale(0), closeTo(squashStartScale, 1e-9));
      expect(
        DropFxMath.squashScale(squashMs * squashDipAt),
        closeTo(squashDipScale, 1e-9),
      );
      expect(
        DropFxMath.squashScale(squashMs * squashOverAt),
        closeTo(squashOverScale, 1e-9),
      );
      expect(DropFxMath.squashScale(squashMs.toDouble()), 1.0);
      expect(DropFxMath.squashScale(squashMs + 500), 1.0);
    });

    test('never leaves the keyframe range', () {
      for (var ms = 0.0; ms <= squashMs; ms += 1) {
        final s = DropFxMath.squashScale(ms);
        expect(s, inInclusiveRange(squashDipScale, squashStartScale));
      }
    });
  });

  group('flash', () {
    test('starts at 0.6, falls monotonically, reaches 0', () {
      expect(DropFxMath.flashAlpha(0), closeTo(flashStartAlpha, 1e-9));
      var last = 1.0;
      for (var ms = 0.0; ms <= flashMs; ms += 5) {
        final a = DropFxMath.flashAlpha(ms);
        expect(a, lessThanOrEqualTo(last));
        last = a;
      }
      expect(DropFxMath.flashAlpha(flashMs.toDouble()), 0);
      expect(DropFxMath.flashAlpha(flashMs + 100), 0);
    });

    test('is quadratic: a quarter in, 0.6 × 0.75²', () {
      expect(
        DropFxMath.flashAlpha(flashMs / 4),
        closeTo(flashStartAlpha * 0.75 * 0.75, 1e-9),
      );
    });
  });

  group('glint', () {
    test('waits, sweeps once, then ends', () {
      expect(DropFxMath.glintProgress(glintDelayMs - 1, 0), isNull);
      expect(DropFxMath.glintProgress(glintDelayMs.toDouble(), 0), 0);
      expect(
        DropFxMath.glintProgress((glintDelayMs + glintMs / 2), 0),
        closeTo(0.5, 1e-9),
      );
      expect(DropFxMath.glintProgress(glintDelayMs + glintMs + 1.0, 0), isNull);
    });

    test('starts 22 ms later per diagonal step', () {
      expect(glintStartMs(0), 70);
      expect(glintStartMs(2), 70 + 2 * glintStaggerMs);
      expect(DropFxMath.glintProgress(glintStartMs(2) - 1.0, 2), isNull);
      expect(DropFxMath.glintProgress(glintStartMs(2) + 1.0, 2), isNotNull);
      expect(DropFxMath.glintProgress(glintStartMs(0) + 1.0, 2), isNull);
    });

    test('diagonal steps count along the piece', () {
      expect(diagonalSteps([cell(2, 3), cell(2, 4), cell(3, 3), cell(3, 4)]), [
        0,
        1,
        1,
        2,
      ]);
      expect(diagonalSteps(const []), isEmpty);
    });
  });

  group('nudge', () {
    test('rests at both ends and peaks in between', () {
      expect(DropFxMath.nudgeFactor(0), 0);
      expect(DropFxMath.nudgeFactor(nudgeMs * nudgePeakAt), closeTo(1, 1e-9));
      expect(DropFxMath.nudgeFactor(nudgeMs.toDouble()), 0);
      expect(DropFxMath.nudgeFactor(nudgeMs + 50), 0);
    });

    test('neighbors are pushed directly away from the piece', () {
      final board = Board()
        ..setCell(0, 0, 1)
        ..setCell(0, 1, 2)
        ..setCell(3, 3, 1)
        ..setCell(1, 0, 1);
      final nudged = nudgedNeighbors([
        cell(0, 1),
        cell(1, 1),
      ], (r, c) => board.cellAt(r, c) != null);
      // (0,1) and (1,1) are the piece; (0,0) and (1,0) touch it from the left.
      expect(nudged.map((n) => (n.row, n.col)).toSet(), {(0, 0), (1, 0)});
      for (final n in nudged) {
        expect(n.dx, -1);
        expect(n.dy, 0);
      }
    });

    test(
      'empty cells and far blocks are not nudged; opposite sides cancel',
      () {
        final board = Board()
          ..setCell(2, 0, 1)
          ..setCell(2, 2, 1)
          ..setCell(7, 7, 1);
        final nudged = nudgedNeighbors([
          cell(2, 1),
        ], (r, c) => board.cellAt(r, c) != null);
        expect(nudged.map((n) => (n.row, n.col)).toSet(), {(2, 0), (2, 2)});
        // A cell pushed from opposite sides has nowhere to go.
        final squeezed = nudgedNeighbors([
          cell(2, 1),
          cell(2, 3),
        ], (r, c) => r == 2 && c == 2);
        expect(squeezed, isEmpty);
      },
    );
  });

  group('ring', () {
    test('grows from 2 to 13 px and fades out', () {
      expect(DropFxMath.ringGap(0), ringStartGap);
      expect(DropFxMath.ringGap(ringMs.toDouble()), ringEndGap);
      expect(DropFxMath.ringGap(ringMs + 100), ringEndGap);
      expect(DropFxMath.ringAlpha(0), ringStartAlpha);
      expect(DropFxMath.ringAlpha(ringMs.toDouble()), 0);
      var last = ringStartGap;
      for (var ms = 0.0; ms <= ringMs; ms += 10) {
        expect(DropFxMath.ringGap(ms), greaterThanOrEqualTo(last));
        last = DropFxMath.ringGap(ms);
      }
    });
  });

  group('thump', () {
    test('dips about 3 px and ends exactly at rest', () {
      expect(DropFxMath.thumpOffset(0), 0);
      var peak = 0.0;
      for (var ms = 0.0; ms < thumpMs; ms += 1) {
        final o = DropFxMath.thumpOffset(ms);
        if (o.abs() > peak.abs()) peak = o;
      }
      expect(peak, greaterThan(thumpDepth * 0.7));
      expect(peak, lessThanOrEqualTo(thumpDepth));
      expect(DropFxMath.thumpOffset(thumpMs.toDouble()), 0);
      expect(DropFxMath.thumpOffset(thumpMs + 100), 0);
    });
  });

  group('points pop and score bump', () {
    test('the +N rises half a cell, holds, fades out', () {
      expect(DropFxMath.popRise(0), 0);
      expect(DropFxMath.popRise(popMs.toDouble()), popRiseCells);
      expect(DropFxMath.popAlpha(0), 1);
      expect(DropFxMath.popAlpha(popMs * popHoldAt), 1);
      expect(DropFxMath.popAlpha(popMs.toDouble()), 0);
    });

    test('the score bumps to 1.16 and returns to 1', () {
      expect(DropFxMath.scoreBump(0), 1);
      expect(
        DropFxMath.scoreBump(scoreBumpMs / 2),
        closeTo(scoreBumpScale, 1e-9),
      );
      expect(DropFxMath.scoreBump(scoreBumpMs.toDouble()), 1);
    });
  });

  group('plan', () {
    test('a plain small drop plays everything except dust and thump', () {
      final p = plan(3);
      expect([
        p.squash,
        p.flash,
        p.glint,
        p.pop,
        p.ring,
        p.nudge,
      ], everyElement(isTrue));
      expect(p.dust, isFalse);
      expect(p.thump, isFalse);
    });

    test('dust starts at 4 cells, the thump at 5', () {
      expect(plan(3).dust, isFalse);
      expect(plan(4).dust, isTrue);
      expect(plan(4).thump, isFalse);
      expect(plan(5).thump, isTrue);
      expect(plan(9).dust && plan(9).thump, isTrue);
    });

    test('a clearing drop plays only squash and flash', () {
      final p = plan(9, clears: true);
      expect(p.squash, isTrue);
      expect(p.flash, isTrue);
      expect([
        p.glint,
        p.pop,
        p.ring,
        p.dust,
        p.thump,
        p.nudge,
      ], everyElement(isFalse));
    });

    test('reduced motion plays only the flash', () {
      final p = plan(9, reduced: true);
      expect(p.flash, isTrue);
      expect([
        p.squash,
        p.glint,
        p.pop,
        p.ring,
        p.dust,
        p.thump,
        p.nudge,
      ], everyElement(isFalse));
      expect(plan(9, reduced: true, clears: true).squash, isFalse);
    });

    test('each switch turns off just its own effect', () {
      expect(
        plan(9, toggles: const DropFxToggles(squash: false)).squash,
        false,
      );
      expect(plan(9, toggles: const DropFxToggles(flash: false)).flash, false);
      expect(plan(9, toggles: const DropFxToggles(glint: false)).glint, false);
      expect(plan(9, toggles: const DropFxToggles(pop: false)).pop, false);
      expect(plan(9, toggles: const DropFxToggles(dust: false)).dust, false);
      expect(plan(9, toggles: const DropFxToggles(thump: false)).thump, false);
      expect(plan(9, toggles: const DropFxToggles(ring: false)).ring, false);
      expect(plan(9, toggles: const DropFxToggles(nudge: false)).nudge, false);
      expect(plan(9, toggles: const DropFxToggles(squash: false)).flash, true);
    });

    test('total time covers the longest effect and the last glint', () {
      expect(plan(1).totalMs(), popMs);
      expect(plan(1).totalMs(maxGlintStep: 4), popMs);
      expect(
        plan(9).totalMs(maxGlintStep: 4),
        glintEndMs(4) > popMs ? glintEndMs(4) : popMs,
      );
      expect(plan(9, clears: true).totalMs(), squashMs);
      expect(plan(9, reduced: true).totalMs(), flashMs);
    });
  });

  group('drop frame', () {
    test('starts at rest and resets to rest', () {
      final f = DropFrame();
      for (var i = 0; i < DropFrame.cells; i++) {
        expect(f.isTouched(i), isFalse);
      }
      f.scale[5] = 1.1;
      f.dx[6] = 2;
      f.glint[7] = 0.3;
      f.flash[8] = 0.2;
      for (final i in [5, 6, 7, 8]) {
        expect(f.isTouched(i), isTrue);
      }
      f.reset();
      for (var i = 0; i < DropFrame.cells; i++) {
        expect(f.isTouched(i), isFalse);
      }
    });
  });
}
