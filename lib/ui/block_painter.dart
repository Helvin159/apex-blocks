import 'dart:math' as math;
import 'dart:ui';

import '../game/piece.dart';
import '../theme/themes.dart';

/// Corner radius of a block on the board.
const double boardBlockRadius = 6;

/// Corner radius of a block at tray size.
const double smallBlockRadius = 4;

/// Corner radius for a block of the given edge length.
double blockRadiusFor(double size) =>
    size >= 28 ? boardBlockRadius : smallBlockRadius;

// Racing-stripe sheen: a thin lighter band at ~115°.
const double _sheenAngle = 115 * math.pi / 180;
const double _sheenCenter = 0.45;
const double _sheenWidth = 0.16;
const double _sheenAlpha = 0.22;

final Paint _fill = Paint();
final Paint _stroke = Paint()..style = PaintingStyle.stroke;

// One gradient shader per (block colors, edge length); shaders are built in
// local coordinates and positioned with a canvas translate.
final Map<(BlockColors, double), Shader> _gradientCache = {};

// Sizes vary continuously while a dragged piece scales, so keep caches bounded.
const int _maxCacheEntries = 128;

Shader _gradient(BlockColors colors, double size) {
  if (_gradientCache.length > _maxCacheEntries) _gradientCache.clear();
  return _gradientCache.putIfAbsent((colors, size), () {
    return Gradient.linear(
      Offset.zero,
      Offset(0, size),
      [colors.light, colors.base, colors.dark],
      const [0, 0.5, 1],
    );
  });
}

final Map<double, Path> _sheenCache = {};

/// The sheen band for a block of edge [size], in local coordinates.
Path _sheen(double size) {
  if (_sheenCache.length > _maxCacheEntries) _sheenCache.clear();
  return _sheenCache.putIfAbsent(size, () {
    final dir = Offset(math.cos(_sheenAngle), math.sin(_sheenAngle));
    final normal = Offset(-dir.dy, dir.dx);
    final mid =
        Offset(size / 2, size / 2) + normal * (_sheenCenter - 0.5) * size;
    final halfLen = size * 1.5;
    final halfW = _sheenWidth * size / 2;
    final a = mid - dir * halfLen - normal * halfW;
    final b = mid + dir * halfLen - normal * halfW;
    final c = mid + dir * halfLen + normal * halfW;
    final d = mid - dir * halfLen + normal * halfW;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
  });
}

/// Draws one block filling [rect] (assumed square).
void paintBlock(
  Canvas canvas,
  Rect rect,
  BlockColors colors, {
  double? radius,
  bool shadow = true,
}) {
  final size = rect.width;
  final r = radius ?? blockRadiusFor(size);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

  if (shadow) {
    canvas.drawRRect(
      rrect.shift(Offset(0, size * 0.07)),
      _fill
        ..shader = null
        ..color = const Color(0x66000000),
    );
  }

  canvas.save();
  canvas.translate(rect.left, rect.top);
  final local = Offset.zero & rect.size;
  final localR = RRect.fromRectAndRadius(local, Radius.circular(r));
  canvas.drawRRect(localR, _fill..shader = _gradient(colors, size));
  _fill.shader = null;

  canvas.save();
  canvas.clipRRect(localR);
  // Darker bottom edge.
  final edge = math.max(1.5, size * 0.07);
  canvas.drawRect(
    Rect.fromLTWH(0, size - edge, size, edge),
    _fill..color = colors.dark.withValues(alpha: 0.85),
  );
  // Racing-stripe sheen.
  canvas.drawPath(
    _sheen(size),
    _fill..color = const Color(0xFFFFFFFF).withValues(alpha: _sheenAlpha),
  );
  canvas.restore();

  // 1 px top highlight, following the rounded top edge.
  canvas.save();
  canvas.clipRect(Rect.fromLTWH(0, 0, size, r));
  canvas.drawRRect(
    localR.deflate(0.5),
    _stroke
      ..strokeWidth = 1
      ..color = colors.light.withValues(alpha: 0.9),
  );
  canvas.restore();
  canvas.restore();
}

/// Draws an empty board cell with a subtle inset shadow.
void paintEmptyCell(Canvas canvas, Rect rect, Color color) {
  final size = rect.width;
  final rrect = RRect.fromRectAndRadius(
    rect,
    Radius.circular(blockRadiusFor(size)),
  );
  canvas.drawRRect(rrect, _fill..color = color);
  canvas.save();
  canvas.clipRRect(rrect);
  canvas.drawRect(
    Rect.fromLTWH(rect.left, rect.top, size, size * 0.35),
    _fill
      ..shader = Gradient.linear(
        rect.topLeft,
        Offset(rect.left, rect.top + size * 0.35),
        const [Color(0x59000000), Color(0x00000000)],
      ),
  );
  _fill.shader = null;
  canvas.drawRect(
    Rect.fromLTWH(rect.left, rect.top, size * 0.25, size),
    _fill
      ..shader = Gradient.linear(
        rect.topLeft,
        Offset(rect.left + size * 0.25, rect.top),
        const [Color(0x33000000), Color(0x00000000)],
      ),
  );
  _fill.shader = null;
  canvas.restore();
}

/// Draws a dashed rounded-rect outline.
void paintDashedRRect(
  Canvas canvas,
  RRect rrect,
  Color color, {
  double strokeWidth = 1.5,
  double dash = 5,
  double gap = 3.5,
}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..color = color;
  final path = Path()..addRRect(rrect);
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      final end = math.min(d + dash, metric.length);
      canvas.drawPath(metric.extractPath(d, end), paint);
      d += dash + gap;
    }
  }
}

/// Pixel size of a piece drawn with the given cell size and gap.
Size pieceExtent(Piece piece, double cell, double gap) => Size(
  piece.width * cell + (piece.width - 1) * gap,
  piece.height * cell + (piece.height - 1) * gap,
);

/// Rect of one piece cell when the piece's top-left is at [topLeft].
Rect pieceCellRect(Offset topLeft, Cell cell, double size, double gap) =>
    Rect.fromLTWH(
      topLeft.dx + cell.col * (size + gap),
      topLeft.dy + cell.row * (size + gap),
      size,
      size,
    );

/// Draws every block of [piece] with its top-left corner at [topLeft].
void paintPiece(
  Canvas canvas,
  Piece piece,
  Offset topLeft,
  double size,
  double gap,
  BlockColors colors, {
  bool shadow = true,
}) {
  for (final cell in piece.cells) {
    paintBlock(
      canvas,
      pieceCellRect(topLeft, cell, size, gap),
      colors,
      shadow: shadow,
    );
  }
}
