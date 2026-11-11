import 'package:flutter/widgets.dart';

/// Default edge of one checker square.
const double checkSize = 4;

const Color _checkLight = Color(0xFFF2F4F7);

/// Fills [rect] with alternating [light] / [dark] squares of [size].
void paintCheckers(
  Canvas canvas,
  Rect rect,
  Color dark, {
  double size = checkSize,
  Color light = _checkLight,
}) {
  final lightPaint = Paint()..color = light;
  final darkPaint = Paint()..color = dark;
  final cols = (rect.width / size).ceil();
  final rows = (rect.height / size).round();
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + c * size, rect.top + r * size, size, size),
        (r + c).isEven ? lightPaint : darkPaint,
      );
    }
  }
}

/// A band of checkers, clipped to its own bounds.
class CheckeredStrip extends StatelessWidget {
  final double height;
  final double size;
  final Color dark;

  const CheckeredStrip({
    super.key,
    required this.dark,
    this.height = 8,
    this.size = checkSize,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _CheckeredPainter(dark: dark, size: size),
      ),
    );
  }
}

class _CheckeredPainter extends CustomPainter {
  final Color dark;
  final double size;

  const _CheckeredPainter({required this.dark, required this.size});

  @override
  void paint(Canvas canvas, Size area) {
    canvas.clipRect(Offset.zero & area);
    paintCheckers(canvas, Offset.zero & area, dark, size: size);
  }

  @override
  bool shouldRepaint(_CheckeredPainter old) =>
      old.dark != dark || old.size != size;
}
