import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/unlocks.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/storage_service.dart';
import '../theme/themes.dart';
import 'block_painter.dart';
import 'checkered.dart';
import 'game_screen.dart';
import 'setup_sheet.dart';
import 'start_lights.dart';

const double _screenPadding = 20;
const double _buttonHeight = 56;
const double _checkerStripHeight = 12;

/// Tilt of the logo cluster, in degrees.
const double _logoTiltDegrees = -8;

String _withCommas(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final AudioService? audio;
  final HapticsService? haptics;

  /// Randomizes the start-light hold; tests pass a seeded one.
  final math.Random? random;

  const HomeScreen({
    super.key,
    required this.storage,
    this.audio,
    this.haptics,
    this.random,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioService _audio = widget.audio ?? AudioService.silent();
  late final HapticsService _haptics =
      widget.haptics ?? HapticsService.silent();
  late final StartSequence _sequence = StartSequence(
    audio: _audio,
    random: widget.random,
    onLit: (count) => setState(() => _litPods = count),
    onGo: _startRun,
  );

  /// Pods currently lit; none when idle.
  int _litPods = 0;

  @override
  void dispose() {
    _sequence.dispose();
    super.dispose();
  }

  Future<void> _startRun() async {
    setState(() {}); // drops the tap-to-skip layer
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          storage: widget.storage,
          audio: _audio,
          haptics: _haptics,
        ),
      ),
    );
    if (mounted) setState(() => _litPods = 0);
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.storage;
    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final theme = storage.theme;
        return Scaffold(
          backgroundColor: theme.background,
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _screenPadding,
                          12,
                          _screenPadding,
                          12,
                        ),
                        child: Column(
                          children: [
                            Text(
                              'ROUND ${storage.gamesPlayed + 1} · ${theme.name.toUpperCase()}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontVariations: const [
                                  FontVariation('wght', 600),
                                ],
                                fontSize: 11,
                                letterSpacing: 1.8,
                                color: theme.muted,
                              ),
                            ),
                            Expanded(
                              child: Center(child: _Logo(theme: theme)),
                            ),
                            StartLightGantry(theme: theme, litPods: _litPods),
                            const SizedBox(height: 14),
                            _LightsOutButton(
                              theme: theme,
                              onTap: _sequence.start,
                            ),
                            const SizedBox(height: 12),
                            _PoleCard(
                              theme: theme,
                              best: storage.bestScore,
                              onLongPress: kDebugMode
                                  ? () => storage.debugAddCareerPoints(1000)
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _LiveryRow(theme: theme, storage: storage),
                            const SizedBox(height: 4),
                            _SetupButton(
                              theme: theme,
                              onTap: () => showSetupSheet(
                                context,
                                storage: storage,
                                audio: _audio,
                                haptics: _haptics,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  CheckeredStrip(
                    dark: theme.background,
                    height: _checkerStripHeight,
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
              // While the lights run, any tap skips straight to the race.
              if (_sequence.isRunning)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => _sequence.skip(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tilted 2×2 block cluster above the APEX / BLOCKS wordmark and tagline.
class _Logo extends StatelessWidget {
  final ApexTheme theme;

  const _Logo({required this.theme});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: _logoTiltDegrees * math.pi / 180,
            child: CustomPaint(
              size: const Size(84, 84),
              painter: _ClusterPainter(theme.preview),
            ),
          ),
          const SizedBox(height: 14),
          Text('APEX', style: _wordmark(theme.text)),
          Text('BLOCKS', style: _wordmark(theme.accent)),
          const SizedBox(height: 6),
          Text(
            'ENDLESS BLOCK RACING',
            style: TextStyle(
              fontFamily: 'Inter',
              fontVariations: const [FontVariation('wght', 600)],
              fontSize: 11,
              letterSpacing: 2.4,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _wordmark(Color color) => TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    fontSize: 64,
    height: 0.95,
    color: color,
  );
}

/// Four blocks in a 2×2 square.
class _ClusterPainter extends CustomPainter {
  final List<BlockColors> colors;

  const _ClusterPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 4.0;
    final cell = (size.width - gap) / 2;
    for (var i = 0; i < 4; i++) {
      paintBlock(
        canvas,
        Rect.fromLTWH(
          (i % 2) * (cell + gap),
          (i ~/ 2) * (cell + gap),
          cell,
          cell,
        ),
        colors[i],
        radius: boardBlockRadius,
      );
    }
  }

  @override
  bool shouldRepaint(_ClusterPainter old) => old.colors != colors;
}

class _LightsOutButton extends StatelessWidget {
  final ApexTheme theme;
  final VoidCallback onTap;

  const _LightsOutButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _buttonHeight,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: const Text(
          'LIGHTS OUT →',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 28,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _PoleCard extends StatelessWidget {
  final ApexTheme theme;
  final int best;

  /// Debug builds only: long-press adds career points to test unlocks.
  final VoidCallback? onLongPress;

  const _PoleCard({required this.theme, required this.best, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.panelAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.pole,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'POLE',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _withCommas(best),
                  style: TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    fontSize: 38,
                    height: 1.05,
                    color: theme.poleLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupButton extends StatelessWidget {
  final ApexTheme theme;
  final VoidCallback onTap;

  const _SetupButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton(
        style: TextButton.styleFrom(foregroundColor: theme.muted),
        onPressed: onTap,
        child: const Text(
          'SETUP',
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _LiveryRow extends StatelessWidget {
  final ApexTheme theme;
  final StorageService storage;

  const _LiveryRow({required this.theme, required this.storage});

  void _onTap(BuildContext context, int i) {
    final career = storage.careerPoints;
    if (isLiveryUnlocked(i, career)) {
      storage.selectLivery(i);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Earn ${_withCommas(liveryUnlockPoints[i])} career points to '
          'unlock ${allLiveries[i].name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final career = storage.careerPoints;
    final selected = storage.selectedLivery;
    return Row(
      children: [
        for (var i = 0; i < allLiveries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _LiveryCard(
              theme: theme,
              livery: allLiveries[i],
              unlockPoints: liveryUnlockPoints[i],
              equipped: i == selected,
              career: career,
              onTap: () => _onTap(context, i),
            ),
          ),
        ],
      ],
    );
  }
}

class _LiveryCard extends StatelessWidget {
  final ApexTheme theme;
  final ApexTheme livery;
  final int unlockPoints;
  final bool equipped;
  final int career;
  final VoidCallback onTap;

  const _LiveryCard({
    required this.theme,
    required this.livery,
    required this.unlockPoints,
    required this.equipped,
    required this.career,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = career < unlockPoints;
    final String status;
    if (equipped) {
      status = 'EQUIPPED';
    } else if (locked) {
      status = '${_withCommas(career)} / ${_withCommas(unlockPoints)} pts';
    } else {
      status = 'UNLOCKED';
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: theme.panelAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: equipped ? theme.accent : theme.border,
            width: equipped ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: locked ? 0.45 : 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(34, 34),
                    painter: _ClusterPainter(livery.preview),
                  ),
                  if (locked)
                    const Icon(Icons.lock, size: 16, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              livery.name.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'BarlowCondensed',
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                fontSize: 14,
                height: 1,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                status,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontVariations: const [FontVariation('wght', 500)],
                  fontSize: 10,
                  color: equipped ? theme.accent : theme.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
