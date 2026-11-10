/// Points awarded for each cell of a placed piece.
const int pointsPerCell = 1;

/// Base for the line bonus: `lineBonusBase × lines²`.
const int lineBonusBase = 10;

/// Multiplier growth per consecutive clear (no cap).
const double comboStep = 0.5;

int placementPoints(int cellCount) => cellCount * pointsPerCell;

int lineBonus(int lines) => lineBonusBase * lines * lines;

/// Multiplier for a clear that follows [streakBefore] consecutive clears.
double comboMultiplier(int streakBefore) =>
    1 + (streakBefore < 0 ? 0 : streakBefore) * comboStep;

/// Bonus points for clearing [lines] lines at the given combo streak. The
/// multiplier applies to the bonus only, not to the per-cell points.
int clearPoints(int lines, int streakBefore) {
  if (lines <= 0) return 0;
  return (lineBonus(lines) * comboMultiplier(streakBefore)).round();
}
