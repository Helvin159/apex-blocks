import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/unlocks.dart';
import '../theme/themes.dart';

const String _bestScoreKey = 'bestScore';
const String _careerPointsKey = 'careerPoints';
const String _gamesPlayedKey = 'gamesPlayed';
const String _firstSessionKey = 'firstSession';
const String _selectedLiveryKey = 'selectedLivery';
const String _soundOnKey = 'soundOn';
const String _hapticsOnKey = 'hapticsOn';

/// What [StorageService.recordRun] changed.
typedef RunRecord = ({int previousBest, bool isNewBest});

/// Persistent player data. Reads are synchronous (values are cached from
/// [SharedPreferences]); listeners are notified after every write.
class StorageService extends ChangeNotifier {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Opens the service on [prefs], or on the app's shared preferences.
  static Future<StorageService> open([SharedPreferences? prefs]) async =>
      StorageService(prefs ?? await SharedPreferences.getInstance());

  int get bestScore => _prefs.getInt(_bestScoreKey) ?? 0;

  /// Sum of the final scores of every finished run.
  int get careerPoints => _prefs.getInt(_careerPointsKey) ?? 0;

  int get gamesPlayed => _prefs.getInt(_gamesPlayedKey) ?? 0;

  /// True until [endFirstSession] is called.
  bool get firstSession => _prefs.getBool(_firstSessionKey) ?? true;

  /// Index of the equipped livery; Night Race if the saved one is locked.
  int get selectedLivery {
    final saved = _prefs.getInt(_selectedLiveryKey) ?? defaultLivery;
    return isLiveryUnlocked(saved, careerPoints) ? saved : defaultLivery;
  }

  /// The equipped livery's colors.
  ApexTheme get theme => allLiveries[selectedLivery];

  bool get soundOn => _prefs.getBool(_soundOnKey) ?? true;

  bool get hapticsOn => _prefs.getBool(_hapticsOnKey) ?? true;

  /// Equips [livery] if it is unlocked; returns whether it was.
  Future<bool> selectLivery(int livery) async {
    if (!isLiveryUnlocked(livery, careerPoints)) return false;
    await _prefs.setInt(_selectedLiveryKey, livery);
    notifyListeners();
    return true;
  }

  Future<void> setSoundOn(bool value) async {
    await _prefs.setBool(_soundOnKey, value);
    notifyListeners();
  }

  Future<void> setHapticsOn(bool value) async {
    await _prefs.setBool(_hapticsOnKey, value);
    notifyListeners();
  }

  /// Debug-build testing aid: adds [points] career points.
  Future<void> debugAddCareerPoints(int points) async {
    assert(kDebugMode);
    if (!kDebugMode) return;
    await _prefs.setInt(_careerPointsKey, careerPoints + points);
    notifyListeners();
  }

  /// Books a finished run: raises the best score if beaten, adds [score] to
  /// career points and counts the game. Call once per run.
  Future<RunRecord> recordRun(int score) async {
    final previousBest = bestScore;
    final isNewBest = score > previousBest;
    await Future.wait([
      _prefs.setInt(_bestScoreKey, math.max(previousBest, score)),
      _prefs.setInt(_careerPointsKey, careerPoints + score),
      _prefs.setInt(_gamesPlayedKey, gamesPlayed + 1),
    ]);
    notifyListeners();
    return (previousBest: previousBest, isNewBest: isNewBest);
  }

  Future<void> endFirstSession() async {
    await _prefs.setBool(_firstSessionKey, false);
    notifyListeners();
  }
}
