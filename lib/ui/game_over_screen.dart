import 'package:flutter/material.dart';

import '../theme/themes.dart';
import 'checkered.dart';

const double _buttonHeight = 52;
const double _flagHeight = 72;
const double _flagSkewX = -0.35;
const double _flagCheck = 12;

/// The Chequered flag screen shown when no piece fits anywhere.
class GameOverScreen extends StatelessWidget {
  final ApexTheme theme;
  final int score;

  /// Best score before this run; decides "NEW POLE!" vs "N to beat it".
  final int previousBest;
  final int linesCleared;
  final int bestCombo;
  final int piecesPlaced;
  final VoidCallback onNewRace;
  final VoidCallback onGarage;

  /// Room for the Pit Stop button (milestone 6); nothing is shown when null.
  final Widget? pitStop;

  const GameOverScreen({
    super.key,
    required this.theme,
    required this.score,
    required this.previousBest,
    required this.linesCleared,
    required this.bestCombo,
    required this.piecesPlaced,
    required this.onNewRace,
    required this.onGarage,
    this.pitStop,
  });

  bool get isNewPole => score > previousBest;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    _FlagBand(theme: theme),
                    const SizedBox(height: 20),
                    Text('CHEQUERED FLAG', style: _display(40, theme.text)),
                    const SizedBox(height: 2),
                    Text(
                      'No room left on the grid',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontVariations: const [FontVariation('wght', 500)],
                        fontSize: 14,
                        color: theme.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ResultCard(
                      theme: theme,
                      score: score,
                      previousBest: previousBest,
                      isNewPole: isNewPole,
                      linesCleared: linesCleared,
                      bestCombo: bestCombo,
                      piecesPlaced: piecesPlaced,
                    ),
                    const SizedBox(height: 18),
                    if (pitStop != null) ...[
                      pitStop!,
                      const SizedBox(height: 12),
                    ],
                    _MenuButton(
                      label: 'NEW RACE',
                      color: theme.accent,
                      onTap: onNewRace,
                    ),
                    const SizedBox(height: 10),
                    _MenuButton(
                      label: 'GARAGE',
                      color: theme.border,
                      textColor: theme.muted,
                      onTap: onGarage,
                    ),
                    if (pitStop != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'One pit stop per race',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: theme.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _display(double size, Color color) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w800,
  fontStyle: FontStyle.italic,
  fontSize: size,
  height: 1,
  color: color,
);

/// A large checkered band, skewed for speed.
class _FlagBand extends StatelessWidget {
  final ApexTheme theme;

  const _FlagBand({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _flagHeight,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(_flagSkewX),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CheckeredStrip(
            dark: theme.panel,
            height: _flagHeight,
            size: _flagCheck,
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ApexTheme theme;
  final int score;
  final int previousBest;
  final bool isNewPole;
  final int linesCleared;
  final int bestCombo;
  final int piecesPlaced;

  const _ResultCard({
    required this.theme,
    required this.score,
    required this.previousBest,
    required this.isNewPole,
    required this.linesCleared,
    required this.bestCombo,
    required this.piecesPlaced,
  });

  @override
  Widget build(BuildContext context) {
    final best = isNewPole ? score : previousBest;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FINISH', style: _label(theme.muted)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('$score', style: _display(54, theme.text)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.pole.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.pole),
                    ),
                    child: Text(
                      'POLE $best',
                      style: _display(16, theme.poleLight),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isNewPole
                        ? 'NEW POLE!'
                        : '${previousBest - score + 1} to beat it',
                    style: isNewPole
                        ? _display(20, theme.pole)
                        : TextStyle(
                            fontFamily: 'Inter',
                            fontVariations: const [FontVariation('wght', 500)],
                            fontSize: 12,
                            color: theme.muted,
                          ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.border),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(theme: theme, label: 'LINES', value: linesCleared),
              _Stat(theme: theme, label: 'BEST COMBO', value: bestCombo),
              _Stat(theme: theme, label: 'PIECES', value: piecesPlaced),
            ],
          ),
        ],
      ),
    );
  }
}

TextStyle _label(Color color) => TextStyle(
  fontFamily: 'Inter',
  fontVariations: const [FontVariation('wght', 600)],
  fontSize: 11,
  letterSpacing: 1.5,
  height: 1,
  color: color,
);

class _Stat extends StatelessWidget {
  final ApexTheme theme;
  final String label;
  final int value;

  const _Stat({required this.theme, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: _display(28, theme.text)),
          const SizedBox(height: 4),
          Text(label, style: _label(theme.muted)),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _buttonHeight,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? color,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
