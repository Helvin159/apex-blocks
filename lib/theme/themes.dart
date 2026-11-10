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
