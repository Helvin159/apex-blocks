import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../game/board.dart';
import '../game/game_state.dart';
import '../game/piece.dart';
import '../theme/themes.dart';
import 'block_painter.dart';
import 'board_geometry.dart';
import 'checkered.dart';
import 'effects/drop_effects.dart';

const double _panelRadius = 14;
const double _weaveSpacing = 6;
const double _weaveAlpha = 0.03;
const double _glowPad = 3;
const double _glowBlur = 5;

/// What the board should draw for the piece currently being dragged over it.
class GhostInfo {
  /// Absolute board cells the piece would cover.
  final List<Cell> cells;
  final int colorId;
  final List<int> clearRows;
  final List<int> clearCols;

  const GhostInfo({
    required this.cells,
    required this.colorId,
    required this.clearRows,
    required this.clearCols,
  });
}

/// The whole board, drawn by a single painter. It repaints when [repaint]
/// (game changes), [ghost] (drag preview) or [dropRepaint] (drop effects on
/// [dropFrame]) notify, without rebuilding.
class BoardView extends StatelessWidget {
  final GameState game;
  final ApexTheme theme;
  final BoardGeometry geometry;
  final Listenable repaint;
  final ValueListenable<GhostInfo?> ghost;
  final DropFrame? dropFrame;
  final Listenable? dropRepaint;

  const BoardView({
    super.key,
    required this.game,
    required this.theme,
    required this.geometry,
    required this.repaint,
    required this.ghost,
    this.dropFrame,
    this.dropRepaint,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: geometry.panelSize,
        painter: BoardPainter(
          game: game,
          theme: theme,
          geometry: geometry,
          ghost: ghost,
          dropFrame: dropFrame,
          repaint: Listenable.merge([repaint, ghost, ?dropRepaint]),
        ),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  final GameState game;
  final ApexTheme theme;
  final BoardGeometry geometry;
  final ValueListenable<GhostInfo?> ghost;
  final DropFrame? dropFrame;

  BoardPainter({
    required this.game,
    required this.theme,
    required this.geometry,
    required this.ghost,
    required Listenable repaint,
    this.dropFrame,
  }) : super(repaint: repaint);

  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur);
  static final Paint _lineOutline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _fx = Paint();
  static final Path _glintPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(_carbon.pictureFor(size, theme));

    final board = game.board;
    final fx = dropFrame;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = geometry.cellRect(r, c);
        final id = board.cellAt(r, c);
        if (id == null) {
          paintEmptyCell(canvas, rect, theme.emptyCell);
        } else if (fx != null && fx.isTouched(DropFrame.indexOf(r, c))) {
          _paintDropBlock(canvas, rect, theme.blocks[id], fx, r, c);
        } else {
          paintBlock(canvas, rect, theme.blocks[id]);
        }
      }
    }

    final g = ghost.value;
    if (g == null) return;
    _paintGhost(canvas, g);
    _paintGlow(canvas, g);
  }

  /// A block mid drop effect: squashed and nudged about its center (the block
  /// itself is drawn at its normal size, so its shader cache stays warm),
  /// then the white flash and the paint glint on top.
  void _paintDropBlock(
    Canvas canvas,
    Rect rect,
    BlockColors colors,
    DropFrame fx,
    int row,
    int col,
  ) {
    final i = DropFrame.indexOf(row, col);
    final center = rect.center;
    canvas.save();
    canvas.translate(center.dx + fx.dx[i], center.dy + fx.dy[i]);
    if (fx.scale[i] != 1.0) canvas.scale(fx.scale[i]);
    canvas.translate(-center.dx, -center.dy);
    paintBlock(canvas, rect, colors);

    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(boardBlockRadius),
    );
    if (fx.flash[i] > 0) {
      canvas.drawRRect(
        rrect,
        _fx..color = const Color(0xFFFFFFFF).withValues(alpha: fx.flash[i]),
      );
    }
    final glint = fx.glint[i];
    if (glint >= 0) _paintGlint(canvas, rect, rrect, glint);
    canvas.restore();
  }

  /// A slanted white band sweeping left to right across one block.
  void _paintGlint(Canvas canvas, Rect rect, RRect rrect, double t) {
    final width = rect.width * glintWidthRatio;
    final skew = rect.height * glintSlant / 2;
    final x = rect.left - width + (rect.width + 2 * width) * t;
    _glintPath
      ..reset()
      ..moveTo(x + skew, rect.top)
      ..lineTo(x + width + skew, rect.top)
      ..lineTo(x + width - skew, rect.bottom)
      ..lineTo(x - skew, rect.bottom)
      ..close();
    // Brightest mid-sweep, faint at both ends.
    final alpha = glintAlpha * math.sin(math.pi * t);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(
      _glintPath,
      _fx..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
    );
    canvas.restore();
  }

  void _paintGhost(Canvas canvas, GhostInfo g) {
    final base = theme.blocks[g.colorId].base;
    final fill = Paint()..color = base.withValues(alpha: 0.16);
    for (final cell in g.cells) {
      final rrect = RRect.fromRectAndRadius(
        geometry.cellRect(cell.row, cell.col).deflate(1),
        const Radius.circular(boardBlockRadius),
      );
      canvas.drawRRect(rrect, fill);
      paintDashedRRect(canvas, rrect, base.withValues(alpha: 0.95));
    }
  }

  void _paintGlow(Canvas canvas, GhostInfo g) {
    final spans = [
      for (final r in g.clearRows) geometry.rowRect(r),
      for (final c in g.clearCols) geometry.colRect(c),
    ];
    for (final span in spans) {
      final rrect = RRect.fromRectAndRadius(
        span.inflate(_glowPad),
        const Radius.circular(boardBlockRadius + _glowPad),
      );
      canvas.drawRRect(rrect, _glowPaint..color = theme.highlight);
      canvas.drawRRect(rrect, _lineOutline..color = theme.highlight);
    }
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.game != game ||
      old.theme != theme ||
      old.geometry.panelWidth != geometry.panelWidth;
}

final _CarbonCache _carbon = _CarbonCache();

/// The static panel (carbon weave, top lift, border, checkered strip),
/// recorded once per size and replayed on every repaint.
class _CarbonCache {
  ui.Picture? _picture;
  Size? _size;
  ApexTheme? _theme;

  ui.Picture pictureFor(Size size, ApexTheme theme) {
    if (_picture == null || _size != size || _theme != theme) {
      _picture?.dispose();
      _picture = _record(size, theme);
      _size = size;
      _theme = theme;
    }
    return _picture!;
  }

  ui.Picture _record(Size size, ApexTheme theme) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & size;
    final panel = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(_panelRadius),
    );

    canvas.drawRRect(panel, Paint()..color = theme.panel);
    canvas.save();
    canvas.clipRRect(panel);

    // Carbon weave: two crossed diagonal stripe patterns.
    final weave = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: _weaveAlpha)
      ..strokeWidth = 2;
    final span = size.width + size.height;
    for (var d = -size.height; d < span; d += _weaveSpacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        weave,
      );
      canvas.drawLine(
        Offset(d + size.height, 0),
        Offset(d, size.height),
        weave,
      );
    }

    // Soft radial lift at the top.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, 0),
          size.width * 0.8,
          [const Color(0x14FFFFFF), const Color(0x00FFFFFF)],
        ),
    );

    // Checkered strip along the top edge.
    paintCheckers(
      canvas,
      Rect.fromLTWH(0, 0, size.width, stripHeight),
      theme.background,
    );
    canvas.restore();

    canvas.drawRRect(
      panel.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.border,
    );
    return recorder.endRecording();
  }
}
