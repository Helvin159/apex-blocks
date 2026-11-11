import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../theme/themes.dart';
import '../block_painter.dart';
import '../board_geometry.dart';
import 'cleared_cells.dart';
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

/// Runs the line-clear overlay: fading ghost blocks, a streak per cleared
/// line, sparks and smoke. A visual layer only; it never touches the game.
///
/// One [Ticker] drives it, started by [trigger] and stopped again when
/// nothing is left to draw.
class ClearEffectsController extends ChangeNotifier {
  final ParticleSystem particles;
  final List<_Burst> _bursts = [];
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _disposed = false;

  ClearEffectsController({
    required TickerProvider vsync,
    ParticleSystem? particles,
  }) : particles = particles ?? ParticleSystem() {
    _ticker = vsync.createTicker(_onTick);
  }

  bool get isActive => _bursts.isNotEmpty || particles.activeCount > 0;

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
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    notifyListeners();
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
    particles.update(dt);
    if (!isActive) _ticker.stop();
    notifyListeners();
  }

  /// Drops everything on screen (a new run starts).
  void clear() {
    _bursts.clear();
    particles.clear();
    if (_ticker.isActive) _ticker.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.dispose();
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
