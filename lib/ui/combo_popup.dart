import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/themes.dart';
import 'popup_text.dart';

/// Pop-in, hold and fade timings of the combo pop-up.
const int popupInMs = 180;
const int popupHoldMs = 600;
const int popupFadeMs = 260;

/// Starting scale of the pop-in.
const double popupStartScale = 0.6;

/// Tilt of the pop-up, in degrees.
const double popupTiltDegrees = -4;

/// One pop-up to show. A new [id] restarts the animation even when the text
/// is the same as last time.
class PopupEvent {
  final int id;
  final PopupText text;

  const PopupEvent(this.id, this.text);
}

/// Italic yellow combo text that pops in, holds, then fades. Shows nothing
/// until [event] first holds a value.
class ComboPopup extends StatefulWidget {
  final ValueListenable<PopupEvent?> event;
  final ApexTheme theme;

  const ComboPopup({super.key, required this.event, required this.theme});

  @override
  State<ComboPopup> createState() => _ComboPopupState();
}

class _ComboPopupState extends State<ComboPopup>
    with SingleTickerProviderStateMixin {
  static const int _totalMs = popupInMs + popupHoldMs + popupFadeMs;

  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  PopupEvent? _shown;

  @override
  void initState() {
    super.initState();
    widget.event.addListener(_onEvent);
  }

  @override
  void didUpdateWidget(ComboPopup old) {
    super.didUpdateWidget(old);
    if (old.event != widget.event) {
      old.event.removeListener(_onEvent);
      widget.event.addListener(_onEvent);
    }
  }

  @override
  void dispose() {
    widget.event.removeListener(_onEvent);
    _ctl.dispose();
    super.dispose();
  }

  void _onEvent() {
    final e = widget.event.value;
    if (e == null) return;
    setState(() => _shown = e);
    _ctl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final e = _shown;
    if (e == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final ms = _ctl.value * _totalMs;
        final inT = (ms / popupInMs).clamp(0.0, 1.0);
        final fadeT = ((ms - popupInMs - popupHoldMs) / popupFadeMs).clamp(
          0.0,
          1.0,
        );
        final scale =
            popupStartScale +
            (1 - popupStartScale) * Curves.easeOutBack.transform(inT);
        return Opacity(
          opacity: (1 - fadeT) * inT,
          child: Transform.rotate(
            angle: popupTiltDegrees * math.pi / 180,
            child: Transform.scale(
              scale: scale,
              child: _PopupBody(text: e.text, theme: widget.theme),
            ),
          ),
        );
      },
    );
  }
}

class _PopupBody extends StatelessWidget {
  final PopupText text;
  final ApexTheme theme;

  const _PopupBody({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final headline = text.headline;
    final detail = text.detail;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (headline != null)
            Text(
              headline,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                fontSize: 28,
                height: 1,
                color: theme.highlight,
              ),
            ),
          if (detail != null)
            Text(
              detail,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                fontSize: headline == null ? 26 : 16,
                height: 1.1,
                letterSpacing: 0.5,
                color: theme.highlight,
              ),
            ),
        ],
      ),
    );
  }
}
