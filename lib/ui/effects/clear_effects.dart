import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game/board.dart';
import '../../game/piece.dart';
import '../../theme/themes.dart';
import '../block_painter.dart';
import '../board_geometry.dart';
import 'cleared_cells.dart';
import 'drop_effects.dart';
import 'particle_system.dart';

/// A white streak sweeps across each cleared line this long.
const int streakMs = 200;

/// Cleared blocks fade out (and swell slightly) over this long.
const int blockFadeMs = 160;

/// Whole effect, streak, sparks and smoke included.
const int effectTotalMs = 500;

/// With reduced motion, cleared blocks just fade over this long.
const int reducedFadeMs = 220;

/// Streak band length as a fraction of the line length.
const double streakLengthRatio = 0.4;
const double streakAlpha = 0.9;

/// Cleared blocks grow by this fraction of a cell as they fade.
const double blockSwellRatio = 0.12;

/// Longest frame step fed to the particles, so a hitch can't fling them.
const double maxFrameStep = 1 / 20;

const int _smokeColor = 0xFF8A9099;
const double _smokeAlpha = 0.3;

/// The "+N" pop's type size as a fraction of the cell size.
const double _popSizeRatio = 0.7;

class _Ghost {
  final Rect rect;
  final BlockColors colors;

  const _Ghost(this.rect, this.colors);
}

class _Streak {
  final Rect rect;
  final bool horizontal;

  const _Streak(this.rect, this.horizontal);
}

class _Burst {
  final List<_Ghost> ghosts;
  final List<_Streak> streaks;
  final bool reduced;
  double age = 0;

  _Burst(this.ghosts, this.streaks, {required this.reduced});

  double get duration =>
      (reduced ? reducedFadeMs : effectTotalMs) /
      Duration.millisecondsPerSecond;
}

/// One placement's drop effects, aging until it is over.
class _DropEvent {
  final DropFxPlan plan;

  /// Placed cells that are still on the board (a cleared one is drawn by the
  /// clear effect instead), with each one's diagonal step for the glint.
  final List<Cell> cells;
  final List<int> steps;
  final List<NudgedCell> nudged;

  /// Rects of every placed cell, and their union's center, for the ring/pop.
  final List<Rect> rects;
  final Offset center;
  final Color ringColor;
  final double cellSize;
  final TextPainter? popText;
  final double totalMs;
  double ageMs = 0;

  _DropEvent({
    required this.plan,
    required this.cells,
    required this.steps,
    required this.nudged,
    required this.rects,
    required this.center,
    required this.ringColor,
    required this.cellSize,
    required this.popText,
    required this.totalMs,
  });
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Runs the line-clear and drop overlays: fading ghost blocks, a streak per
/// cleared line, sparks and smoke, plus the per-placement drop effects. A
/// visual layer only; it never touches the game.
///
/// One [Ticker] drives it all, started by [trigger] / [triggerDrop] and
/// stopped again when nothing is left to draw.
class ClearEffectsController extends ChangeNotifier {
  final ParticleSystem particles;
  final math.Random _random;
  final List<_Burst> _bursts = [];
  final List<_DropEvent> _drops = [];
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _disposed = false;
  bool _frameDirty = false;

  /// Per-cell squash, flash, glint and nudge for the board painter.
  final DropFrame dropFrame = DropFrame();
  final _Repaint _dropRepaint = _Repaint();

  /// Notifies when [dropFrame] changed.
  Listenable get dropRepaint => _dropRepaint;

  /// Board thump: how far the board is shifted down, in px.
  final ValueNotifier<double> thumpDy = ValueNotifier(0);

  /// Scale of the score number (1 = at rest).
  final ValueNotifier<double> scoreBump = ValueNotifier(1);

  ClearEffectsController({
    required TickerProvider vsync,
    ParticleSystem? particles,
    math.Random? random,
  }) : particles = particles ?? ParticleSystem(),
       _random = random ?? math.Random() {
    _ticker = vsync.createTicker(_onTick);
  }

  bool get isActive =>
      _bursts.isNotEmpty || _drops.isNotEmpty || particles.activeCount > 0;

  /// Drop events still playing (for tests).
  int get dropCount => _drops.length;

  /// The effects of the newest drop still playing, if any (for tests).
  DropFxPlan? get latestDropPlan => _drops.isEmpty ? null : _drops.last.plan;

  /// Starts the effect for [cells] (with [rows] and [cols] cleared) on a
  /// board laid out by [geometry]. Rects are in board-panel coordinates.
  void trigger({
    required List<ClearedCell> cells,
    required List<int> rows,
    required List<int> cols,
    required BoardGeometry geometry,
    required ApexTheme theme,
    bool reducedMotion = false,
  }) {
    if (cells.isEmpty || _disposed) return;
    final ghosts = [
      for (final c in cells)
        _Ghost(geometry.cellRect(c.row, c.col), theme.blocks[c.colorId]),
    ];
    final streaks = reducedMotion
        ? const <_Streak>[]
        : [
            for (final r in rows) _Streak(geometry.rowRect(r), true),
            for (final c in cols) _Streak(geometry.colRect(c), false),
          ];
    if (!reducedMotion) {
      for (final c in cells) {
        final rect = geometry.cellRect(c.row, c.col);
        particles.burstCell(
          rect.center.dx,
          rect.center.dy,
          rect.width,
          sparkColor: theme.blocks[c.colorId].light.toARGB32(),
          smokeColor: _smokeColor,
        );
      }
    }
    _bursts.add(_Burst(ghosts, streaks, reduced: reducedMotion));
    _startTicker();
    notifyListeners();
  }

  /// Starts the drop effects for a piece just placed on [placed] (absolute
  /// board cells). [board] is the board after the placement. A drop that
  /// [clearsLines] only squashes and flashes; the clear effect takes over.
  void triggerDrop({
    required List<Cell> placed,
    required int colorId,
    required Board board,
    required BoardGeometry geometry,
    required ApexTheme theme,
    required bool clearsLines,
    bool reducedMotion = false,
  }) {
    if (placed.isEmpty || _disposed) return;
    final plan = DropFxPlan.forDrop(
      cellCount: placed.length,
      clearsLines: clearsLines,
      reducedMotion: reducedMotion,
    );
    if (!plan.any) return;

    final allSteps = diagonalSteps(placed);
    final cells = <Cell>[];
    final steps = <int>[];
    for (var i = 0; i < placed.length; i++) {
      if (board.cellAt(placed[i].row, placed[i].col) == null) continue;
      cells.add(placed[i]);
      steps.add(allSteps[i]);
    }
    final rects = [for (final c in placed) geometry.cellRect(c.row, c.col)];
    final bounds = rects.reduce((a, b) => a.expandToInclude(b));
    final cell = geometry.cellSize;
    final light = theme.blocks[colorId].light;

    TextPainter? popText;
    if (plan.pop) {
      popText = TextPainter(
        text: TextSpan(
          text: '+${placed.length}',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: cell * _popSizeRatio,
            color: theme.highlight,
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    _drops.add(
      _DropEvent(
        plan: plan,
        cells: cells,
        steps: steps,
        nudged: plan.nudge
            ? nudgedNeighbors(placed, (r, c) => board.cellAt(r, c) != null)
            : const [],
        rects: rects,
        center: bounds.center,
        ringColor: light,
        cellSize: cell,
        popText: popText,
        totalMs: plan
            .totalMs(maxGlintStep: steps.isEmpty ? 0 : steps.reduce(math.max))
            .toDouble(),
      ),
    );
    if (plan.dust) _spawnDust(placed, geometry);
    _syncDrops();
    _startTicker();
    notifyListeners();
  }

  /// Two small gray puffs per piece column, from the bottom edge, drifting
  /// out and down. They live in the shared particle pool (and its cap).
  void _spawnDust(List<Cell> placed, BoardGeometry geometry) {
    final bottoms = <int, int>{};
    for (final c in placed) {
      final row = bottoms[c.col];
      if (row == null || c.row > row) bottoms[c.col] = c.row;
    }
    final mid =
        (bottoms.keys.reduce(math.min) + bottoms.keys.reduce(math.max)) / 2;
    final cell = geometry.cellSize;
    bottoms.forEach((col, row) {
      final rect = geometry.cellRect(row, col);
      final side = col == mid
          ? (_random.nextBool() ? 1.0 : -1.0)
          : (col < mid ? -1.0 : 1.0);
      for (var i = 0; i < dustPuffsPerColumn; i++) {
        particles.spawnSmoke(
          x: rect.center.dx + (_random.nextDouble() - 0.5) * cell * 0.5,
          y: rect.bottom - cell * 0.08,
          vx: side * dustDriftX * (0.4 + _random.nextDouble() * 0.6),
          vy:
              dustDriftYMin +
              _random.nextDouble() * (dustDriftYMax - dustDriftYMin),
          life:
              dustLifeMin + _random.nextDouble() * (dustLifeMax - dustLifeMin),
          size: cell * dustStartRatio,
          growth: cell * dustGrowthRatio,
          color: _smokeColor,
        );
      }
    });
  }

  void _startTicker() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min(
      (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond,
      maxFrameStep,
    );
    _last = elapsed;
    for (final b in _bursts) {
      b.age += dt;
    }
    _bursts.removeWhere((b) => b.age >= b.duration);
    for (final d in _drops) {
      d.ageMs += dt * Duration.millisecondsPerSecond;
    }
    _removeFinishedDrops();
    particles.update(dt);
    _syncDrops();
    if (!isActive) _ticker.stop();
    notifyListeners();
  }

  void _removeFinishedDrops() {
    _drops.removeWhere((d) {
      final done = d.ageMs >= d.totalMs;
      if (done) d.popText?.dispose();
      return done;
    });
  }

  /// Recomputes [dropFrame], [thumpDy] and [scoreBump] from the live drops.
  /// Pings the board painter while drops play and once more when they end,
  /// so the board is redrawn at rest.
  void _syncDrops() {
    dropFrame.reset();
    var thump = 0.0;
    var bump = 1.0;
    for (final d in _drops) {
      final ms = d.ageMs;
      final plan = d.plan;
      final scale = plan.squash ? DropFxMath.squashScale(ms) : 1.0;
      final flash = plan.flash ? DropFxMath.flashAlpha(ms) : 0.0;
      for (var k = 0; k < d.cells.length; k++) {
        final i = DropFrame.indexOf(d.cells[k].row, d.cells[k].col);
        dropFrame.scale[i] = scale;
        dropFrame.flash[i] = flash;
        if (plan.glint) {
          dropFrame.glint[i] = DropFxMath.glintProgress(ms, d.steps[k]) ?? -1;
        }
      }
      if (plan.nudge) {
        final f = DropFxMath.nudgeFactor(ms) * nudgeDistance;
        if (f > 0) {
          for (final n in d.nudged) {
            final i = DropFrame.indexOf(n.row, n.col);
            dropFrame.dx[i] += n.dx * f;
            dropFrame.dy[i] += n.dy * f;
          }
        }
      }
      if (plan.thump) thump += DropFxMath.thumpOffset(ms);
      if (plan.pop) bump = math.max(bump, DropFxMath.scoreBump(ms));
    }
    thumpDy.value = thump;
    scoreBump.value = bump;
    if (_drops.isNotEmpty || _frameDirty) _dropRepaint.ping();
    _frameDirty = _drops.isNotEmpty;
  }

  /// Drops everything on screen (a new run starts).
  void clear() {
    _bursts.clear();
    for (final d in _drops) {
      d.popText?.dispose();
    }
    _drops.clear();
    particles.clear();
    if (_ticker.isActive) _ticker.stop();
    _syncDrops();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
    for (final d in _drops) {
      d.popText?.dispose();
    }
    _drops.clear();
    _dropRepaint.dispose();
    thumpDy.dispose();
    scoreBump.dispose();
    super.dispose();
  }
}

/// Draws a [ClearEffectsController] over the board, in board-panel
/// coordinates.
class ClearEffectsPainter extends CustomPainter {
  final ClearEffectsController controller;
  final double cellSize;

  ClearEffectsPainter({required this.controller, required this.cellSize})
    : super(repaint: controller);

  final Paint _paint = Paint();
  final Paint _line = Paint()..strokeCap = StrokeCap.round;
  final Paint _ring = Paint()..style = PaintingStyle.stroke;
  // Streak gradients, built once per band length and reused every frame.
  ui.Shader? _horizontalShader;
  ui.Shader? _verticalShader;
  double _shaderLength = -1;

  @override
  void paint(Canvas canvas, Size size) {
    for (final burst in controller._bursts) {
      _paintGhosts(canvas, burst);
      for (final streak in burst.streaks) {
        _paintStreak(canvas, burst, streak);
      }
    }
    for (final drop in controller._drops) {
      if (drop.plan.ring) _paintRing(canvas, drop);
    }
    final system = controller.particles;
    // Smoke first so sparks sit on top.
    for (var i = 0; i < system.activeCount; i++) {
      final p = system.at(i);
      if (p.kind == ParticleKind.smoke) _paintSmoke(canvas, p);
    }
    for (var i = 0; i < system.activeCount; i++) {
      final p = system.at(i);
      if (p.kind == ParticleKind.spark) _paintSpark(canvas, p);
    }
    for (final drop in controller._drops) {
      if (drop.plan.pop) _paintPop(canvas, drop);
    }
  }

  /// A rounded outline hugging the piece, growing outward and fading.
  void _paintRing(Canvas canvas, _DropEvent drop) {
    final alpha = DropFxMath.ringAlpha(drop.ageMs);
    if (alpha <= 0 || drop.ageMs >= ringMs) return;
    // A hair extra so neighbouring cells' outlines overlap into one shape.
    final gap = DropFxMath.ringGap(drop.ageMs);
    final inflate = gap + 0.5;
    Path? outline;
    for (final rect in drop.rects) {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect.inflate(inflate),
            Radius.circular(boardBlockRadius + inflate),
          ),
        );
      outline = outline == null
          ? shape
          : Path.combine(PathOperation.union, outline, shape);
    }
    canvas.drawPath(
      outline!,
      _ring
        ..strokeWidth = ringStrokeWidth
        ..color = drop.ringColor.withValues(alpha: alpha),
    );
  }

  /// "+N" rising from the middle of the piece and fading out.
  void _paintPop(Canvas canvas, _DropEvent drop) {
    final text = drop.popText;
    if (text == null || drop.ageMs >= popMs) return;
    final alpha = DropFxMath.popAlpha(drop.ageMs);
    if (alpha <= 0) return;
    final rise = DropFxMath.popRise(drop.ageMs) * drop.cellSize;
    final origin = Offset(
      drop.center.dx - text.width / 2,
      drop.center.dy - text.height / 2 - rise,
    );
    canvas.saveLayer(
      (origin & text.size).inflate(8),
      _paint..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    text.paint(canvas, origin);
    canvas.restore();
  }

  void _paintGhosts(Canvas canvas, _Burst burst) {
    final fadeSeconds =
        (burst.reduced ? reducedFadeMs : blockFadeMs) /
        Duration.millisecondsPerSecond;
    final t = (burst.age / fadeSeconds).clamp(0.0, 1.0);
    if (t >= 1) return;
    final alpha = 1 - Curves.easeIn.transform(t);
    final grow = burst.reduced ? 0.0 : blockSwellRatio * t * cellSize / 2;
    for (final g in burst.ghosts) {
      _paint.color = g.colors.base.withValues(alpha: alpha);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          g.rect.inflate(grow),
          const Radius.circular(boardBlockRadius),
        ),
        _paint,
      );
    }
  }

  void _paintStreak(Canvas canvas, _Burst burst, _Streak streak) {
    final t = burst.age / (streakMs / Duration.millisecondsPerSecond);
    if (t >= 1) return;
    final rect = streak.rect;
    final length =
        (streak.horizontal ? rect.width : rect.height) * streakLengthRatio;
    _ensureShaders(length);
    // The band enters before the line and leaves past its far end.
    final travel = (streak.horizontal ? rect.width : rect.height) + length;
    final pos = -length + travel * Curves.easeOut.transform(t);
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    _paint.color = Color.fromRGBO(255, 255, 255, streakAlpha * fade);

    canvas.save();
    canvas.clipRect(rect.inflate(2));
    if (streak.horizontal) {
      canvas.translate(rect.left + pos, rect.top - 2);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, length, rect.height + 4),
        _paint..shader = _horizontalShader,
      );
    } else {
      canvas.translate(rect.left - 2, rect.top + pos);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, rect.width + 4, length),
        _paint..shader = _verticalShader,
      );
    }
    _paint.shader = null;
    canvas.restore();
  }

  void _ensureShaders(double length) {
    if ((length - _shaderLength).abs() < 0.01) return;
    _shaderLength = length;
    const stops = [0.0, 0.7, 1.0];
    const colors = [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)];
    _horizontalShader = ui.Gradient.linear(
      Offset.zero,
      Offset(length, 0),
      colors,
      stops,
    );
    _verticalShader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, length),
      colors,
      stops,
    );
  }

  void _paintSmoke(Canvas canvas, Particle p) {
    _paint.color = Color(p.color)
        .withValues(alpha: _smokeAlpha * p.lifeFraction);
    canvas.drawCircle(Offset(p.x, p.y), p.size, _paint);
  }

  void _paintSpark(Canvas canvas, Particle p) {
    // A short trail behind the spark, along its velocity.
    const trail = 0.035;
    _line
      ..strokeWidth = p.size
      ..color = Color(p.color).withValues(alpha: p.lifeFraction.clamp(0, 1));
    canvas.drawLine(
      Offset(p.x, p.y),
      Offset(p.x - p.vx * trail, p.y - p.vy * trail),
      _line,
    );
  }

  @override
  bool shouldRepaint(ClearEffectsPainter old) =>
      old.controller != controller || old.cellSize != cellSize;
}

/// The overlay widget: sits above the board, ignores all touches, and only
/// repaints itself.
class ClearEffectsOverlay extends StatelessWidget {
  final ClearEffectsController controller;
  final BoardGeometry geometry;

  const ClearEffectsOverlay({
    super.key,
    required this.controller,
    required this.geometry,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: geometry.panelSize,
          painter: ClearEffectsPainter(
            controller: controller,
            cellSize: geometry.cellSize,
          ),
        ),
      ),
    );
  }
}
