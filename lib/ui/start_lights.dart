import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../services/audio_service.dart';
import '../theme/themes.dart';

/// Pods in the gantry.
const int gantryPods = 5;

/// Lights per pod.
const int lightsPerPod = 2;

/// Time between one pod lighting and the next.
const int lightStepMs = 350;

/// After the last pod lights, the lights hold for a random time in this range.
const int holdMinMs = 200;
const int holdMaxMs = 600;

/// Beat between the lights going out and the race starting.
const int goDelayMs = 150;

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

/// The start sequence: pods light one at a time with a beep each, hold for a
/// random time, then all go out with a whoosh and the race starts.
///
/// Runs on timers, so it is testable with fake async. [skip] jumps straight
/// to the race.
class StartSequence {
  final AudioService audio;
  final Random _random;

  /// Called with the number of lit pods (0 to [gantryPods]).
  final ValueChanged<int> onLit;

  /// Called once when the race should start.
  final VoidCallback onGo;

  Timer? _timer;
  bool _running = false;

  StartSequence({
    required this.audio,
    required this.onLit,
    required this.onGo,
    Random? random,
  }) : _random = random ?? Random();

  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _lightPod(1);
  }

  void _lightPod(int count) {
    onLit(count);
    audio.playLight();
    if (count < gantryPods) {
      _timer = Timer(
        const Duration(milliseconds: lightStepMs),
        () => _lightPod(count + 1),
      );
    } else {
      final hold = holdMinMs + _random.nextInt(holdMaxMs - holdMinMs + 1);
      _timer = Timer(Duration(milliseconds: hold), _lightsOut);
    }
  }

  void _lightsOut() {
    onLit(0);
    audio.playLightsOut();
    _timer = Timer(const Duration(milliseconds: goDelayMs), _go);
  }

  void _go() {
    _running = false;
    _timer = null;
    onGo();
  }

  /// Cancels the sequence and starts the race now (no whoosh).
  void skip() {
    if (!_running) return;
    _timer?.cancel();
    onLit(0);
    _go();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
