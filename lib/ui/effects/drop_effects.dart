import 'dart:math' as math;
import 'dart:typed_data';

import '../../game/board.dart';
import '../../game/piece.dart';

// Pure Dart: no Flutter imports, so the math is unit-testable.
//
// Every placement gets a few small, quick visual rewards. They never block
// input and never touch the game. Each one sits behind its own switch below;
// set it to false to turn that effect off everywhere.

const bool dropFxSquash = true;
const bool dropFxFlash = true;
const bool dropFxGlint = true;

/// The "+N" pop and the score number's bump.
const bool dropFxPointsPop = true;
const bool dropFxDust = true;
const bool dropFxThump = true;
const bool dropFxRing = true;
const bool dropFxNudge = true;

// Times are in milliseconds, distances in logical pixels.

/// Landing squash: new blocks go 1.14 → 0.93 → 1.035 → 1.0.
const int squashMs = 170;
const double squashStartScale = 1.14;
const double squashDipScale = 0.93;
const double squashOverScale = 1.035;

/// When the dip and the overshoot land, as fractions of [squashMs].
const double squashDipAt = 0.4;
const double squashOverAt = 0.72;

/// Impact flash: a white overlay on new blocks, fading quadratically.
const int flashMs = 150;
const double flashStartAlpha = 0.6;

/// Paint glint: a slanted white band sweeping across each new block.
const int glintMs = 260;
const int glintDelayMs = 70;

/// Extra delay per step along the piece's diagonal.
const int glintStaggerMs = 22;
const double glintAlpha = 0.55;

/// Band width as a fraction of the block, and its slant.
const double glintWidthRatio = 0.34;
const double glintSlant = 0.5;

/// Points pop: "+N" rises and fades, and the score number bumps.
const int popMs = 560;

/// How far the "+N" rises, in cells.
const double popRiseCells = 0.5;

/// The "+N" holds full opacity this long (fraction of [popMs]), then fades.
const double popHoldAt = 0.35;
const int scoreBumpMs = 220;
const double scoreBumpScale = 1.16;

/// Tyre dust: small gray puffs from the bottom edge of big pieces.
const int dustMinCells = 4;
const int dustPuffsPerColumn = 2;
const double dustLifeMin = 0.3;
const double dustLifeMax = 0.42;

/// Sideways drift (px/s), downward drift (px/s), puff radius and growth as
/// fractions of the cell size.
const double dustDriftX = 46;
const double dustDriftYMin = 14;
const double dustDriftYMax = 34;
const double dustStartRatio = 0.16;
const double dustGrowthRatio = 0.5;

/// Board thump: the board dips and wobbles back to rest.
const int thumpMinCells = 5;
const int thumpMs = 170;
const double thumpDepth = 3;

/// Wobble cycles within [thumpMs].
const double thumpWobbles = 1.5;

/// Shockwave ring: grows from [ringStartGap] to [ringEndGap] beyond the piece.
const int ringMs = 260;
const double ringStartGap = 2;
const double ringEndGap = 13;
const double ringStartAlpha = 0.9;
const double ringStrokeWidth = 2;

/// Neighbor nudge: touching blocks shift away and spring back.
const int nudgeMs = 200;
const double nudgeDistance = 2.6;

/// The nudge reaches its peak here (fraction of [nudgeMs]).
const double nudgePeakAt = 0.3;

/// Which effects a drop plays.
class DropFxToggles {
  final bool squash, flash, glint, pop, dust, thump, ring, nudge;

  const DropFxToggles({
    this.squash = dropFxSquash,
    this.flash = dropFxFlash,
    this.glint = dropFxGlint,
    this.pop = dropFxPointsPop,
    this.dust = dropFxDust,
    this.thump = dropFxThump,
    this.ring = dropFxRing,
    this.nudge = dropFxNudge,
  });
}

/// The effects one drop plays, decided from its size and what it did.
class DropFxPlan {
  final bool squash, flash, glint, pop, dust, thump, ring, nudge;

  const DropFxPlan({
    this.squash = false,
    this.flash = false,
    this.glint = false,
    this.pop = false,
    this.dust = false,
    this.thump = false,
    this.ring = false,
    this.nudge = false,
  });

  /// - Reduced motion: only the impact flash.
  /// - A drop that clears a line: only squash and flash; the clear effect and
  ///   its pop-up take over from there.
  /// - Dust needs [dustMinCells]+ cells, the thump [thumpMinCells]+.
  factory DropFxPlan.forDrop({
    required int cellCount,
    required bool clearsLines,
    required bool reducedMotion,
    DropFxToggles toggles = const DropFxToggles(),
  }) {
    if (reducedMotion) return DropFxPlan(flash: toggles.flash);
    if (clearsLines) {
      return DropFxPlan(squash: toggles.squash, flash: toggles.flash);
    }
    return DropFxPlan(
      squash: toggles.squash,
      flash: toggles.flash,
      glint: toggles.glint,
      pop: toggles.pop,
      dust: toggles.dust && cellCount >= dustMinCells,
      thump: toggles.thump && cellCount >= thumpMinCells,
      ring: toggles.ring,
      nudge: toggles.nudge,
    );
  }

  bool get any =>
      squash || flash || glint || pop || dust || thump || ring || nudge;

  /// When the whole drop is over, for a piece whose glint stagger tops out at
  /// [maxGlintStep]. Dust is driven by the particle pool, not by this.
  int totalMs({int maxGlintStep = 0}) {
    var total = 0;
    if (squash) total = math.max(total, squashMs);
    if (flash) total = math.max(total, flashMs);
    if (glint) {
      total = math.max(total, glintEndMs(maxGlintStep));
    }
    if (pop) total = math.max(total, math.max(popMs, scoreBumpMs));
    if (thump) total = math.max(total, thumpMs);
    if (ring) total = math.max(total, ringMs);
    if (nudge) total = math.max(total, nudgeMs);
    return total;
  }
}

/// When the glint of the cell at diagonal [step] starts.
int glintStartMs(int step) => glintDelayMs + glintStaggerMs * step;

int glintEndMs(int step) => glintStartMs(step) + glintMs;

/// The animation curves. All take the elapsed milliseconds since the drop and
/// settle exactly at rest once their duration has passed.
abstract final class DropFxMath {
  static double _unit(double ms, int duration) =>
      duration <= 0 ? 1.0 : (ms / duration).clamp(0.0, 1.0);

  static double _smooth(double t) => t * t * (3 - 2 * t);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _easeOut(double t) => 1 - (1 - t) * (1 - t);

  /// Scale of a landing block: 1.14 → 0.93 → 1.035 → 1.0.
  static double squashScale(double ms) {
    final t = _unit(ms, squashMs);
    if (t >= 1) return 1.0;
    if (t < squashDipAt) {
      return _lerp(squashStartScale, squashDipScale, _smooth(t / squashDipAt));
    }
    if (t < squashOverAt) {
      return _lerp(
        squashDipScale,
        squashOverScale,
        _smooth((t - squashDipAt) / (squashOverAt - squashDipAt)),
      );
    }
    return _lerp(
      squashOverScale,
      1.0,
      _smooth((t - squashOverAt) / (1 - squashOverAt)),
    );
  }

  /// Alpha of the white impact flash: 0.6 fading to 0 (quadratic).
  static double flashAlpha(double ms) {
    final t = _unit(ms, flashMs);
    return flashStartAlpha * (1 - t) * (1 - t);
  }

  /// Progress 0..1 of the glint on the cell at diagonal [step], or null when
  /// it has not started or is over.
  static double? glintProgress(double ms, int step) {
    final local = ms - glintStartMs(step);
    if (local < 0 || local >= glintMs) return null;
    return local / glintMs;
  }

  /// How far a neighbor is pushed, 0..1: out quickly, then back to rest.
  static double nudgeFactor(double ms) {
    final t = _unit(ms, nudgeMs);
    if (t <= 0 || t >= 1) return 0;
    if (t < nudgePeakAt) return _smooth(t / nudgePeakAt);
    return 1 - _smooth((t - nudgePeakAt) / (1 - nudgePeakAt));
  }

  /// Gap between the piece and its ring, [ringStartGap] → [ringEndGap].
  static double ringGap(double ms) =>
      _lerp(ringStartGap, ringEndGap, _easeOut(_unit(ms, ringMs)));

  static double ringAlpha(double ms) =>
      ringStartAlpha * (1 - _unit(ms, ringMs));

  /// Downward shift of the board: a damped wobble that ends at exactly 0.
  static double thumpOffset(double ms) {
    final t = _unit(ms, thumpMs);
    if (t >= 1) return 0;
    return thumpDepth * (1 - t * t) * math.sin(2 * math.pi * thumpWobbles * t);
  }

  /// How far the "+N" has risen, in cells.
  static double popRise(double ms) => popRiseCells * _easeOut(_unit(ms, popMs));

  /// Opacity of the "+N": full, then fading out.
  static double popAlpha(double ms) {
    final t = _unit(ms, popMs);
    if (t <= popHoldAt) return 1;
    return 1 - (t - popHoldAt) / (1 - popHoldAt);
  }

  /// Scale of the score number: 1 → 1.16 → 1.
  static double scoreBump(double ms) {
    final t = _unit(ms, scoreBumpMs);
    if (t <= 0 || t >= 1) return 1.0;
    return 1 + (scoreBumpScale - 1) * math.sin(math.pi * t);
  }
}

/// A block touching the new piece, and the unit direction it is pushed in.
typedef NudgedCell = ({int row, int col, double dx, double dy});

/// Occupied cells that touch [placed] along an edge, each with the direction
/// pointing away from the piece. [occupied] says whether a board cell holds a
/// block (after the placement).
List<NudgedCell> nudgedNeighbors(
  List<Cell> placed,
  bool Function(int row, int col) occupied,
) {
  final inPiece = {for (final c in placed) c.row * boardSize + c.col};
  final push = <int, ({double dx, double dy})>{};
  const around = [(-1, 0), (1, 0), (0, -1), (0, 1)];
  for (final c in placed) {
    for (final (dr, dc) in around) {
      final r = c.row + dr;
      final col = c.col + dc;
      if (r < 0 || col < 0 || r >= boardSize || col >= boardSize) continue;
      final key = r * boardSize + col;
      if (inPiece.contains(key) || !occupied(r, col)) continue;
      final prev = push[key] ?? (dx: 0.0, dy: 0.0);
      push[key] = (dx: prev.dx + dc, dy: prev.dy + dr);
    }
  }
  final out = <NudgedCell>[];
  push.forEach((key, v) {
    final length = math.sqrt(v.dx * v.dx + v.dy * v.dy);
    // Pushed from opposite sides: nowhere to go.
    if (length == 0) return;
    out.add((
      row: key ~/ boardSize,
      col: key % boardSize,
      dx: v.dx / length,
      dy: v.dy / length,
    ));
  });
  return out;
}

/// Diagonal step of each placed cell: 0 for the top-left-most diagonal, up by
/// one per diagonal after that. Staggers the glint along the piece.
List<int> diagonalSteps(List<Cell> placed) {
  if (placed.isEmpty) return const [];
  final low = placed.map((c) => c.row + c.col).reduce(math.min);
  return [for (final c in placed) c.row + c.col - low];
}

/// What the board painter needs for one frame, per board cell. Preallocated
/// and reused, so a frame costs no allocations.
class DropFrame {
  static const int cells = boardSize * boardSize;

  /// Block scale (1 = at rest).
  final Float64List scale = Float64List(cells);

  /// White flash alpha (0 = none).
  final Float64List flash = Float64List(cells);

  /// Glint progress 0..1, or -1 for none.
  final Float64List glint = Float64List(cells);

  /// Nudge offset in px.
  final Float64List dx = Float64List(cells);
  final Float64List dy = Float64List(cells);

  DropFrame() {
    reset();
  }

  static int indexOf(int row, int col) => row * boardSize + col;

  /// Back to everything at rest.
  void reset() {
    scale.fillRange(0, cells, 1.0);
    flash.fillRange(0, cells, 0.0);
    glint.fillRange(0, cells, -1.0);
    dx.fillRange(0, cells, 0.0);
    dy.fillRange(0, cells, 0.0);
  }

  /// True if the cell is drawn any differently from at rest.
  bool isTouched(int i) =>
      scale[i] != 1.0 ||
      flash[i] > 0 ||
      glint[i] >= 0 ||
      dx[i] != 0 ||
      dy[i] != 0;
}
