import 'dart:ui';

/// Light / base / dark stops for one block color's vertical gradient.
class BlockColors {
  final Color light;
  final Color base;
  final Color dark;

  const BlockColors(this.light, this.base, this.dark);
}

/// Color tokens for one livery.
class ApexTheme {
  final String name;
  final Color background;
  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color emptyCell;
  final Color text;
  final Color muted;
  final Color accent;
  final Color pole;
  final Color poleLight;
  final Color highlight;

  /// Indexed by game color id (0–5): red, yellow, white, teal, green, purple.
  final List<BlockColors> blocks;

  const ApexTheme({
    required this.name,
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.emptyCell,
    required this.text,
    required this.muted,
    required this.accent,
    required this.pole,
    required this.poleLight,
    required this.highlight,
    required this.blocks,
  });
}

const ApexTheme nightRace = ApexTheme(
  name: 'Night Race',
  background: Color(0xFF0A0C10),
  panel: Color(0xFF111419),
  panelAlt: Color(0xFF13161B),
  border: Color(0xFF2A2F37),
  emptyCell: Color(0xFF1A1E25),
  text: Color(0xFFF2F4F7),
  muted: Color(0xFF9AA3AF),
  accent: Color(0xFFFF2D3A),
  pole: Color(0xFF9B5CFF),
  poleLight: Color(0xFFC9A2FF),
  highlight: Color(0xFFFFC22E),
  blocks: [
    BlockColors(Color(0xFFFF6B76), Color(0xFFF2334A), Color(0xFFB51C30)),
    BlockColors(Color(0xFFFFE27A), Color(0xFFFFC22E), Color(0xFFC78B00)),
    BlockColors(Color(0xFFFFFFFF), Color(0xFFDDE3EA), Color(0xFF9AA4B1)),
    BlockColors(Color(0xFF6FF2E6), Color(0xFF1FC8BA), Color(0xFF0E8C83)),
    BlockColors(Color(0xFF8BF0A6), Color(0xFF34D46A), Color(0xFF1E9446)),
    BlockColors(Color(0xFFC9A2FF), Color(0xFF9B5CFF), Color(0xFF6A31C9)),
  ],
);

/// Career points needed to unlock the Rain Race livery (tune after testing).
const int rainRaceUnlockPoints = 5000;

/// Career points needed to unlock the Desert Dusk livery (tune after testing).
const int desertDuskUnlockPoints = 15000;

/// A livery as shown on the Home screen.
class LiveryInfo {
  final String name;

  /// Career points that unlock it; 0 means always available.
  final int unlockPoints;

  /// Four block colors for the mini 2×2 preview.
  final List<BlockColors> preview;

  const LiveryInfo({
    required this.name,
    required this.unlockPoints,
    required this.preview,
  });
}

/// Preview-only colors until the liveries become full themes.
const List<LiveryInfo> liveries = [
  LiveryInfo(
    name: 'Night Race',
    unlockPoints: 0,
    preview: [
      BlockColors(Color(0xFFFF6B76), Color(0xFFF2334A), Color(0xFFB51C30)),
      BlockColors(Color(0xFFFFE27A), Color(0xFFFFC22E), Color(0xFFC78B00)),
      BlockColors(Color(0xFF6FF2E6), Color(0xFF1FC8BA), Color(0xFF0E8C83)),
      BlockColors(Color(0xFFC9A2FF), Color(0xFF9B5CFF), Color(0xFF6A31C9)),
    ],
  ),
  LiveryInfo(
    name: 'Rain Race',
    unlockPoints: rainRaceUnlockPoints,
    preview: [
      BlockColors(Color(0xFF8CC8FF), Color(0xFF3D8BE8), Color(0xFF1F5AA8)),
      BlockColors(Color(0xFFB4E1FF), Color(0xFF5DB0F0), Color(0xFF2E78B8)),
      BlockColors(Color(0xFF9FB8FF), Color(0xFF5273E0), Color(0xFF2F46A0)),
      BlockColors(Color(0xFFE6F2FF), Color(0xFFB6CCE6), Color(0xFF7890AE)),
    ],
  ),
  LiveryInfo(
    name: 'Desert Dusk',
    unlockPoints: desertDuskUnlockPoints,
    preview: [
      BlockColors(Color(0xFFFFB066), Color(0xFFF08A2E), Color(0xFFB8591A)),
      BlockColors(Color(0xFFF5E2B8), Color(0xFFE0C48C), Color(0xFFA68A58)),
      BlockColors(Color(0xFFFFA3A8), Color(0xFFE5666E), Color(0xFFA83A44)),
      BlockColors(Color(0xFFFFD08A), Color(0xFFF2A83C), Color(0xFFB87818)),
    ],
  ),
];
