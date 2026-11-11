import '../game/game_state.dart';
import 'audio_service.dart';

/// Minimum time between two pass-by sounds.
const int passbyCooldownMs = 4000;

/// Lines cleared in one placement that count as a FASTEST LAP!.
const int fastestLapLines = 3;

/// Which sounds play for one placement.
class SoundPlan {
  /// Clear chime variant (1 to [clearVariantCount]), or null for no clear.
  final int? chimeVariant;

  /// Whether the short pass-by plays.
  final bool passby;

  /// Whether this move passed Pole for the first time this run, whether or not
  /// the pass-by was allowed to play.
  final bool polePassed;

  const SoundPlan({
    required this.chimeVariant,
    required this.passby,
    required this.polePassed,
  });
}

/// Decides the sounds for a placement that left the run at [scoreAfter].
///
/// [poleBefore] is the best score when the run started. [polePassedAlready]
/// is whether this run already passed it. [msSinceLastPassby] is the time
/// since any pass-by last played (null if none has). The pass-by plays at most
/// once per move, for FASTEST LAP! or the first Pole pass (only when there was
/// a Pole to pass), and not inside the cooldown.
SoundPlan soundPlanFor({
  required PlacementResult result,
  required int scoreAfter,
  required int poleBefore,
  required bool polePassedAlready,
  required int? msSinceLastPassby,
}) {
  final lines = result.clearedRows.length + result.clearedCols.length;
  final polePassed =
      !polePassedAlready && poleBefore > 0 && scoreAfter > poleBefore;
  final big = lines >= fastestLapLines || polePassed;
  final cooledDown =
      msSinceLastPassby == null || msSinceLastPassby >= passbyCooldownMs;
  return SoundPlan(
    chimeVariant: lines > 0 ? clearVariant(result.comboAfter) : null,
    passby: big && cooledDown,
    polePassed: polePassed,
  );
}
