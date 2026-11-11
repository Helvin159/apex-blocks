// Livery unlock rules. Pure Dart: liveries are identified by index
// (0 Night Race, 1 Rain Race, 2 Desert Dusk), matching `allLiveries`.

/// Career points needed to unlock the Rain Race livery (tune after testing).
const int rainRaceUnlockPoints = 5000;

/// Career points needed to unlock the Desert Dusk livery (tune after testing).
const int desertDuskUnlockPoints = 15000;

/// Career points that unlock each livery; 0 means always available.
const List<int> liveryUnlockPoints = [
  0,
  rainRaceUnlockPoints,
  desertDuskUnlockPoints,
];

/// Index of the default livery (Night Race).
const int defaultLivery = 0;

bool isLiveryUnlocked(int livery, int careerPoints) =>
    livery >= 0 &&
    livery < liveryUnlockPoints.length &&
    careerPoints >= liveryUnlockPoints[livery];

/// Indices of every livery unlocked at [careerPoints].
List<int> unlockedLiveries(int careerPoints) => [
  for (var i = 0; i < liveryUnlockPoints.length; i++)
    if (isLiveryUnlocked(i, careerPoints)) i,
];

/// Progress toward a livery: points earned (capped at the target) and target.
({int current, int target}) liveryProgress(int livery, int careerPoints) {
  final target = liveryUnlockPoints[livery];
  return (
    current: careerPoints < target ? careerPoints : target,
    target: target,
  );
}

/// Liveries a run unlocked: locked at [before] career points, unlocked at
/// [after].
List<int> newlyUnlocked(int before, int after) => [
  for (var i = 0; i < liveryUnlockPoints.length; i++)
    if (!isLiveryUnlocked(i, before) && isLiveryUnlocked(i, after)) i,
];
