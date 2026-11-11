import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gap between the impacts of the "rumble strip" pattern.
const int rumbleGapMs = 45;

/// Light impacts in the rumble strip.
const int rumbleLightCount = 4;

/// Combo at which a clear adds the rumble strip.
const int rumbleMinCombo = 3;

enum HapticKind { light, medium }

/// One impact, [delayMs] after the placement.
typedef HapticStep = ({HapticKind kind, int delayMs});

/// The impacts for one placement: a light tap, a medium impact when lines
/// cleared, and on a clear with combo ≥ [rumbleMinCombo] a rumble strip of
/// [rumbleLightCount] light impacts after the medium one.
List<HapticStep> hapticStepsFor({
  required int linesCleared,
  required int comboAfter,
}) {
  if (linesCleared <= 0) return const [(kind: HapticKind.light, delayMs: 0)];
  return [
    (kind: HapticKind.medium, delayMs: 0),
    if (comboAfter >= rumbleMinCombo)
      for (var i = 1; i <= rumbleLightCount; i++)
        (kind: HapticKind.light, delayMs: i * rumbleGapMs),
  ];
}

/// Haptic feedback. [HapticsService.silent] does nothing and is the default
/// for tests.
class HapticsService {
  /// Haptics on/off. A settings toggle arrives in a later milestone.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  final bool _silent;
  final Set<Timer> _timers = {};

  HapticsService() : _silent = false;

  HapticsService.silent() : _silent = true;

  void onPlacement({required int linesCleared, required int comboAfter}) {
    if (_silent || !enabled.value) return;
    for (final step in hapticStepsFor(
      linesCleared: linesCleared,
      comboAfter: comboAfter,
    )) {
      if (step.delayMs == 0) {
        _fire(step.kind);
      } else {
        late final Timer timer;
        timer = Timer(Duration(milliseconds: step.delayMs), () {
          _timers.remove(timer);
          if (enabled.value) _fire(step.kind);
        });
        _timers.add(timer);
      }
    }
  }

  void _fire(HapticKind kind) => switch (kind) {
    HapticKind.light => HapticFeedback.lightImpact(),
    HapticKind.medium => HapticFeedback.mediumImpact(),
  };

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    enabled.dispose();
  }
}
