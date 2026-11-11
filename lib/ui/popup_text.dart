import '../game/game_state.dart';

/// Lines cleared in one placement that earn "FASTEST LAP!".
const int fastestLapLines = 3;

/// Lines cleared in one placement that earn "SLIPSTREAM!".
const int slipstreamLines = 2;

/// Combo count (consecutive clears, this one included) from which a
/// single-line clear earns "OVERTAKE!" and the combo line is shown.
const int overtakeCombo = 2;

/// What the combo pop-up says: a headline (may be absent) and a second line.
class PopupText {
  final String? headline;
  final String? detail;

  const PopupText({this.headline, this.detail});

  @override
  bool operator ==(Object other) =>
      other is PopupText &&
      other.headline == headline &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(headline, detail);

  @override
  String toString() => 'PopupText($headline, $detail)';
}

/// The pop-up for [result], or null when nothing was cleared.
///
/// The combo is `comboAfter`: the first clear is 1, the next consecutive
/// clear 2, and so on.
PopupText? popupFor(PlacementResult result) {
  final lines = result.clearedRows.length + result.clearedCols.length;
  if (lines == 0) return null;
  final combo = result.comboAfter;

  final String? headline;
  if (lines >= fastestLapLines) {
    headline = 'FASTEST LAP!';
  } else if (lines == slipstreamLines) {
    headline = 'SLIPSTREAM!';
  } else if (combo >= overtakeCombo) {
    headline = 'OVERTAKE!';
  } else {
    headline = null;
  }

  final String? detail;
  if (combo >= overtakeCombo) {
    detail = 'COMBO ×$combo · +${result.pointsGained}';
  } else if (headline == null) {
    detail = '+${result.pointsGained}';
  } else {
    detail = null;
  }
  return PopupText(headline: headline, detail: detail);
}
