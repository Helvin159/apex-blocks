import 'package:flutter/widgets.dart';

import '../theme/themes.dart';

/// Pods in the gantry.
const int gantryPods = 5;

/// Lights per pod.
const int lightsPerPod = 2;

const Color _unlit = Color(0xFF2A1013);

/// The start-light gantry: a row of pods, each with two red lights.
/// Pods below [litPods] are lit.
class StartLightGantry extends StatelessWidget {
  final ApexTheme theme;
  final int litPods;
  final double height;

  const StartLightGantry({
    super.key,
    required this.theme,
    this.litPods = gantryPods,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _GantryPainter(theme, litPods),
      ),
    );
  }
}

class _GantryPainter extends CustomPainter {
  final ApexTheme theme;
  final int litPods;

  const _GantryPainter(this.theme, this.litPods);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 8.0;
    final podW = (size.width - (gantryPods - 1) * gap) / gantryPods;
    final lightR = (podW / 2 - 8).clamp(4.0, size.height * 0.14);
    for (var i = 0; i < gantryPods; i++) {
      final pod = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (podW + gap), 0, podW, size.height),
        const Radius.circular(10),
      );
      canvas.drawRRect(pod, Paint()..color = theme.panelAlt);
      canvas.drawRRect(
        pod.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = theme.border,
      );
      final lit = i < litPods;
      for (var j = 0; j < lightsPerPod; j++) {
        final c = Offset(
          pod.left + podW / 2,
          size.height * (j + 1) / (lightsPerPod + 1),
        );
        if (lit) {
          canvas.drawCircle(
            c,
            lightR * 1.9,
            Paint()
              ..color = theme.accent.withValues(alpha: 0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }
        canvas.drawCircle(
          c,
          lightR,
          Paint()..color = lit ? theme.accent : _unlit,
        );
        if (lit) {
          canvas.drawCircle(
            c - Offset(lightR * 0.25, lightR * 0.3),
            lightR * 0.35,
            Paint()..color = const Color(0x66FFFFFF),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GantryPainter old) =>
      old.theme != theme || old.litPods != litPods;
}
