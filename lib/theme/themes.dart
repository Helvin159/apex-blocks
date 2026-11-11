import 'dart:ui';

/// Light / base / dark stops for one block color's vertical gradient.
class BlockColors {
  final Color light;
  final Color base;
  final Color dark;

  const BlockColors(this.light, this.base, this.dark);
}

/// Color tokens for one livery. Pole purple, the highlight yellow and the
/// start-light red are the same in every livery.
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

  /// Indexed by game color id (0–5), in the order the livery defines.
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

  /// Four block colors for the mini 2×2 previews and the logo cluster.
  List<BlockColors> get preview => [for (final i in _previewIds) blocks[i]];
}

const List<int> _previewIds = [0, 1, 3, 5];

const Color _pole = Color(0xFF9B5CFF);
const Color _poleLight = Color(0xFFC9A2FF);
const Color _highlight = Color(0xFFFFC22E);

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
  pole: _pole,
  poleLight: _poleLight,
  highlight: _highlight,
  blocks: [
    BlockColors(Color(0xFFFF6B76), Color(0xFFF2334A), Color(0xFFB51C30)),
    BlockColors(Color(0xFFFFE27A), Color(0xFFFFC22E), Color(0xFFC78B00)),
    BlockColors(Color(0xFFFFFFFF), Color(0xFFDDE3EA), Color(0xFF9AA4B1)),
    BlockColors(Color(0xFF6FF2E6), Color(0xFF1FC8BA), Color(0xFF0E8C83)),
    BlockColors(Color(0xFF8BF0A6), Color(0xFF34D46A), Color(0xFF1E9446)),
    BlockColors(Color(0xFFC9A2FF), Color(0xFF9B5CFF), Color(0xFF6A31C9)),
  ],
);

const ApexTheme rainRace = ApexTheme(
  name: 'Rain Race',
  background: Color(0xFF070D18),
  panel: Color(0xFF0E1726),
  panelAlt: Color(0xFF111B2C),
  border: Color(0xFF23324A),
  emptyCell: Color(0xFF142036),
  text: Color(0xFFEEF4FB),
  muted: Color(0xFF93A4BC),
  accent: Color(0xFF1F7FD0),
  pole: _pole,
  poleLight: _poleLight,
  highlight: _highlight,
  blocks: [
    BlockColors(Color(0xFF9FD8FF), Color(0xFF3BA4F0), Color(0xFF1B6AAE)),
    BlockColors(Color(0xFFFFFFFF), Color(0xFFD9EAF7), Color(0xFF8FA9C2)),
    BlockColors(Color(0xFF7BF0E4), Color(0xFF19C2B2), Color(0xFF0B847A)),
    BlockColors(Color(0xFFB8C2FF), Color(0xFF6E7CF2), Color(0xFF3F48B3)),
    BlockColors(Color(0xFFC3CFDD), Color(0xFF7F93AB), Color(0xFF4E5F75)),
    BlockColors(Color(0xFFD5B8FF), Color(0xFFA178F2), Color(0xFF6B44B8)),
  ],
);

const ApexTheme desertDusk = ApexTheme(
  name: 'Desert Dusk',
  background: Color(0xFF120B08),
  panel: Color(0xFF1C130F),
  panelAlt: Color(0xFF201612),
  border: Color(0xFF3A2A21),
  emptyCell: Color(0xFF26190F),
  text: Color(0xFFF7EFE8),
  muted: Color(0xFFB9A595),
  accent: Color(0xFFD9581A),
  pole: _pole,
  poleLight: _poleLight,
  highlight: _highlight,
  blocks: [
    BlockColors(Color(0xFFFFB27A), Color(0xFFFF7A2E), Color(0xFFC24A0A)),
    BlockColors(Color(0xFFFFE3B0), Color(0xFFF2C27A), Color(0xFFB98A44)),
    BlockColors(Color(0xFFFF9AA8), Color(0xFFE8566C), Color(0xFFA62A3E)),
    BlockColors(Color(0xFFFFF6E6), Color(0xFFEADFC8), Color(0xFFB3A387)),
    BlockColors(Color(0xFFE88A6A), Color(0xFFC5573A), Color(0xFF8A3320)),
    BlockColors(Color(0xFFD6A6E8), Color(0xFFA35FC2), Color(0xFF6E3389)),
  ],
);

/// Every livery, indexed to match the unlock rules in `game/unlocks.dart`.
const List<ApexTheme> allLiveries = [nightRace, rainRace, desertDusk];

/// Colors that stay the same in every livery.
const Color startLightRed = Color(0xFFFF2D3A);
