import 'package:apexblocks/services/ad_rules.dart';
import 'package:flutter_test/flutter_test.dart';

bool due({
  int games = 3,
  int? ms = 120000,
  bool first = false,
  bool removed = false,
}) => shouldShowInterstitial(
  gameOversSinceLast: games,
  msSinceLast: ms,
  isFirstSession: first,
  adsRemoved: removed,
);

void main() {
  group('shouldShowInterstitial', () {
    test('constants', () {
      expect(interstitialEvery, 3);
      expect(interstitialMinGapMs, 90000);
    });

    test('shows on the 3rd game over, not the 1st or 2nd', () {
      expect(due(games: 0), isFalse);
      expect(due(games: 1), isFalse);
      expect(due(games: 2), isFalse);
      expect(due(games: 3), isTrue);
    });

    test('a skipped slot is still due at the next game over', () {
      expect(due(games: 4), isTrue);
      expect(due(games: 7), isTrue);
    });

    test('needs at least 90 s since the last one', () {
      expect(due(ms: 89999), isFalse);
      expect(due(ms: 90000), isTrue);
      expect(due(ms: 0), isFalse);
    });

    test('none shown yet this process: the gap rule passes', () {
      expect(due(ms: null), isTrue);
    });

    test('never in the first session', () {
      expect(due(first: true), isFalse);
      expect(due(first: true, games: 99, ms: null), isFalse);
    });

    test('never when ads are removed', () {
      expect(due(removed: true), isFalse);
      expect(due(removed: true, games: 99, ms: null), isFalse);
    });

    test('every condition must hold', () {
      expect(due(), isTrue);
      expect(due(games: 2), isFalse);
      expect(due(ms: 1000), isFalse);
      expect(due(first: true), isFalse);
      expect(due(removed: true), isFalse);
    });
  });

  group('isPitStopEligible', () {
    bool eligible({
      bool used = false,
      bool loaded = true,
      bool allowed = true,
      bool recorded = false,
    }) => isPitStopEligible(
      usedThisRun: used,
      adLoaded: loaded,
      adsAllowed: allowed,
      runRecorded: recorded,
    );

    test('offered when unused, loaded and allowed', () {
      expect(eligible(), isTrue);
    });

    test('each missing condition hides it', () {
      expect(eligible(used: true), isFalse);
      expect(eligible(loaded: false), isFalse);
      expect(eligible(allowed: false), isFalse);
      expect(eligible(recorded: true), isFalse);
    });
  });

  group('isLiveryUnlockedWith', () {
    bool unlocked(int livery, {int career = 0, int ads = 0}) =>
        isLiveryUnlockedWith(
          livery: livery,
          careerPoints: career,
          adsWatched: ads,
        );

    test('Night Race is always unlocked', () {
      expect(unlocked(0), isTrue);
    });

    test('career points unlock', () {
      expect(unlocked(1, career: 4999), isFalse);
      expect(unlocked(1, career: 5000), isTrue);
      expect(unlocked(2, career: 14999), isFalse);
      expect(unlocked(2, career: 15000), isTrue);
    });

    test('3 rewarded ads unlock', () {
      expect(unlocked(1, ads: 2), isFalse);
      expect(unlocked(1, ads: 3), isTrue);
      expect(unlocked(2, ads: liveryAdsRequired), isTrue);
    });

    test('out-of-range liveries stay locked', () {
      expect(unlocked(-1, ads: 3), isFalse);
      expect(unlocked(3, ads: 3, career: 99999), isFalse);
    });
  });
}
