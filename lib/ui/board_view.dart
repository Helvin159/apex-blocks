import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../game/board.dart';
import '../game/game_state.dart';
import '../game/piece.dart';
import '../theme/themes.dart';
import 'block_painter.dart';
import 'board_geometry.dart';

const double _panelRadius = 14;
const double _checkSize = 4;
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
/// (game changes) or [ghost] (drag preview) notify, without rebuilding.
class BoardView extends StatelessWidget {
  final GameState game;
  final ApexTheme theme;
  final BoardGeometry geometry;
  final Listenable repaint;
  final ValueListenable<GhostInfo?> ghost;

  const BoardView({
    super.key,
    required this.game,
    required this.theme,
    required this.geometry,
    required this.repaint,
    required this.ghost,
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
          repaint: Listenable.merge([repaint, ghost]),
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

  BoardPainter({
    required this.game,
    required this.theme,
    required this.geometry,
    required this.ghost,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur);
  static final Paint _lineOutline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(_carbon.pictureFor(size, theme));

    final board = game.board;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = geometry.cellRect(r, c);
        final id = board.cellAt(r, c);
        if (id == null) {
          paintEmptyCell(canvas, rect, theme.emptyCell);
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
    final light = Paint()..color = const Color(0xFFF2F4F7);
    final dark = Paint()..color = theme.background;
    final cols = (size.width / _checkSize).ceil();
    final rows = (stripHeight / _checkSize).round();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * _checkSize, r * _checkSize, _checkSize, _checkSize),
          (r + c).isEven ? light : dark,
        );
      }
    }
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
