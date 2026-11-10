/// Points awarded for each cell of a placed piece.
const int pointsPerCell = 1;

/// Base for the line bonus: `lineBonusBase × lines²`.
const int lineBonusBase = 10;

/// Clear-bonus multiplier by combo streak (0-based: the first clear in a
/// streak uses index 0). Streaks beyond the end use the last entry.
const List<double> comboMultipliers = [1.0, 1.5, 2.0];

int placementPoints(int cellCount) => cellCount * pointsPerCell;

int lineBonus(int lines) => lineBonusBase * lines * lines;

/// Multiplier for a clear that follows [streakBefore] consecutive clears.
double comboMultiplier(int streakBefore) {
  final i = streakBefore.clamp(0, comboMultipliers.length - 1);
  return comboMultipliers[i];
}

/// Bonus points for clearing [lines] lines at the given combo streak. The
/// multiplier applies to the bonus only, not to the per-cell points.
int clearPoints(int lines, int streakBefore) {
  if (lines <= 0) return 0;
  return (lineBonus(lines) * comboMultiplier(streakBefore)).round();
}
