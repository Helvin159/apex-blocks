import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Number of clear-sound variants (combo 1 to 6+).
const int clearVariantCount = 6;

/// Players preloaded per sound, so rapid repeats overlap instead of cutting
/// each other off.
const int placePlayers = 4;
const int clearPlayers = 2;
const int lightPlayers = 2;
const int passbyPlayers = 1;

/// Per-sound volume (0 to 1). The pass-by is loudest in the mix but kept
/// below full scale so it is never painful on a phone speaker.
const double placeVolume = 0.7;
const double chimeVolume = 0.8;
const double passbyVolume = 0.65;

/// Which clear sound (1 to [clearVariantCount]) to play for a placement whose
/// combo count afterwards is [comboAfter].
int clearVariant(int comboAfter) => comboAfter.clamp(1, clearVariantCount);

/// Sound effects. [AudioService.silent] never touches a plugin and is the
/// default for tests; `main.dart` creates the real one.
class AudioService {
  /// Sound on/off. A settings toggle arrives in a later milestone.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  final bool _silent;
  final Map<String, _SoundPool> _pools = {};
  bool _ready = false;

  AudioService() : _silent = false;

  AudioService.silent() : _silent = true;

  /// Sets the audio session and preloads every sound. Never throws: a device
  /// without working audio just plays silently.
  Future<void> init() async {
    if (_silent) return;
    try {
      final context = AudioContext(
        // Ambient: silenced by the silent switch, mixes with the user's music.
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
        // No audio focus request, so other apps are never ducked or paused.
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      );
      await AudioPlayer.global.setAudioContext(context);
      await Future.wait([
        _load('place', placePlayers, context, placeVolume),
        for (var i = 1; i <= clearVariantCount; i++)
          _load('clear_$i', clearPlayers, context, chimeVolume),
        _load('light', lightPlayers, context, 1.0),
        _load('passby_full', passbyPlayers, context, passbyVolume),
        _load('passby_short', passbyPlayers, context, passbyVolume),
      ]);
      _ready = true;
    } catch (e, st) {
      debugPrint('AudioService.init failed: $e\n$st');
    }
  }

  Future<void> _load(
    String name,
    int players,
    AudioContext context,
    double volume,
  ) async {
    final pool = _SoundPool(
      AssetSource('sfx/$name.wav'),
      players,
      context,
      volume,
    );
    await pool.load();
    _pools[name] = pool;
  }

  void _play(String name) {
    if (_silent || !_ready || !enabled.value) return;
    _pools[name]?.play();
  }

  void playPlace() => _play('place');

  void playClear(int comboAfter) => _play('clear_${clearVariant(comboAfter)}');

  void playLight() => _play('light');

  /// The full car fly-by, when the lights go out.
  void playPassbyFull() {
    notePassby();
    _play('passby_full');
  }

  /// The short fly-by for big moments.
  void playPassbyShort() {
    notePassby();
    _play('passby_short');
  }

  DateTime? _lastPassby;

  /// Records that a pass-by is playing now (for the cooldown).
  @protected
  void notePassby() => _lastPassby = DateTime.now();

  /// Milliseconds since a pass-by last played, or null if none has.
  int? get msSincePassby => _lastPassby == null
      ? null
      : DateTime.now().difference(_lastPassby!).inMilliseconds;

  Future<void> dispose() async {
    enabled.dispose();
    await Future.wait(_pools.values.map((p) => p.dispose()));
    _pools.clear();
  }
}

/// A fixed set of preloaded low-latency players for one sound, used
/// round-robin. A repeat restarts the oldest player.
class _SoundPool {
  final Source source;
  final int size;
  final AudioContext context;
  final double volume;
  final List<AudioPlayer> _players = [];
  int _next = 0;

  _SoundPool(this.source, this.size, this.context, this.volume);

  Future<void> load() async {
    for (var i = 0; i < size; i++) {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setAudioContext(context);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.setSource(source);
      _players.add(player);
    }
  }

  void play() {
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    // Platform calls run in order, so stop lands before resume.
    player.stop().then((_) => player.resume()).catchError((Object e) {
      debugPrint('Sound failed: $e');
    });
  }

  Future<void> dispose() async {
    await Future.wait(_players.map((p) => p.dispose()));
    _players.clear();
  }
}
