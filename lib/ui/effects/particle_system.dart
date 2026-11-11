import 'dart:math';

// Pure Dart: no Flutter imports, so the math is unit-testable.

/// Hard cap on live particles. Spawns beyond it are dropped.
const int maxParticles = 220;

/// Particles spawned per cleared cell.
const int sparksPerCell = 5;
const int smokePerCell = 1;

// Times are in seconds, distances in logical pixels.
const double sparkLifeMin = 0.28;
const double sparkLifeMax = 0.5;
const double smokeLifeMin = 0.4;
const double smokeLifeMax = 0.5;

/// Spark launch speed range, in px/s.
const double sparkSpeedMin = 90;
const double sparkSpeedMax = 270;

/// Downward pull on sparks, in px/s².
const double sparkGravity = 520;

/// Sparks and smoke lose this fraction of their speed per second.
const double sparkDrag = 1.2;
const double smokeDrag = 2.5;

/// Smoke drifts up at this speed (px/s), starts at this fraction of the cell
/// size and grows by [smokeGrowthRatio] × cell size per second.
const double smokeRise = 34;
const double smokeStartRatio = 0.28;
const double smokeGrowthRatio = 0.55;

/// Spark thickness as a fraction of the cell size.
const double sparkSizeRatio = 0.07;

enum ParticleKind { spark, smoke }

/// One pooled particle. Fields are mutated in place; never hold on to one
/// after it expires, because the pool hands it out again.
class Particle {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;

  /// Seconds left.
  double life = 0;
  double maxLife = 1;

  /// Spark thickness or smoke radius, in px.
  double size = 0;

  /// Size change per second (smoke puffs grow).
  double growth = 0;

  /// 0xAARRGGBB.
  int color = 0;
  ParticleKind kind = ParticleKind.spark;

  /// Fraction of life remaining, 1 (new) to 0 (expired).
  double get lifeFraction => maxLife <= 0 ? 0 : (life / maxLife).clamp(0, 1);
}

/// A fixed pool of particles. Everything is allocated up front; live ones
/// are kept in the first [activeCount] slots.
class ParticleSystem {
  final Random _random;
  final List<Particle> _pool;
  int _active = 0;

  ParticleSystem({int capacity = maxParticles, Random? random})
    : _random = random ?? Random(),
      _pool = List.generate(capacity, (_) => Particle(), growable: false);

  int get capacity => _pool.length;

  int get activeCount => _active;

  /// The i-th live particle, 0 ≤ i < [activeCount].
  Particle at(int i) => _pool[i];

  /// Takes a particle from the pool, or returns null at the cap.
  Particle? _take() => _active < _pool.length ? _pool[_active++] : null;

  /// Spawns one spark. Returns false when the pool is full.
  bool spawnSpark({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required double size,
    required int color,
  }) => _spawn(ParticleKind.spark, x, y, vx, vy, life, size, 0, color);

  bool spawnSmoke({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required double size,
    required double growth,
    required int color,
  }) => _spawn(ParticleKind.smoke, x, y, vx, vy, life, size, growth, color);

  bool _spawn(
    ParticleKind kind,
    double x,
    double y,
    double vx,
    double vy,
    double life,
    double size,
    double growth,
    int color,
  ) {
    final p = _take();
    if (p == null) return false;
    p
      ..kind = kind
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..life = life
      ..maxLife = life
      ..size = size
      ..growth = growth
      ..color = color;
    return true;
  }

  /// Bursts one cleared cell centered at ([cx], [cy]): [sparksPerCell]
  /// sparks in [sparkColor] and [smokePerCell] smoke puffs in [smokeColor].
  /// Returns how many particles were spawned (fewer near the cap).
  int burstCell(
    double cx,
    double cy,
    double cellSize, {
    required int sparkColor,
    required int smokeColor,
  }) {
    var spawned = 0;
    for (var i = 0; i < sparksPerCell; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed =
          sparkSpeedMin +
          _random.nextDouble() * (sparkSpeedMax - sparkSpeedMin);
      final ok = spawnSpark(
        x: cx + (_random.nextDouble() - 0.5) * cellSize * 0.6,
        y: cy + (_random.nextDouble() - 0.5) * cellSize * 0.6,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life:
            sparkLifeMin + _random.nextDouble() * (sparkLifeMax - sparkLifeMin),
        size: max(1.5, cellSize * sparkSizeRatio),
        color: sparkColor,
      );
      if (ok) spawned++;
    }
    for (var i = 0; i < smokePerCell; i++) {
      final ok = spawnSmoke(
        x: cx + (_random.nextDouble() - 0.5) * cellSize * 0.4,
        y: cy + (_random.nextDouble() - 0.5) * cellSize * 0.4,
        vx: (_random.nextDouble() - 0.5) * 30,
        vy: -smokeRise * (0.6 + _random.nextDouble() * 0.8),
        life:
            smokeLifeMin + _random.nextDouble() * (smokeLifeMax - smokeLifeMin),
        size: cellSize * smokeStartRatio,
        growth: cellSize * smokeGrowthRatio,
        color: smokeColor,
      );
      if (ok) spawned++;
    }
    return spawned;
  }

  /// Advances every live particle by [dt] seconds and recycles expired ones.
  void update(double dt) {
    if (dt <= 0) return;
    var i = 0;
    while (i < _active) {
      final p = _pool[i];
      p.life -= dt;
      if (p.life <= 0) {
        // Swap with the last live particle and shrink the live range.
        _active--;
        _pool[i] = _pool[_active];
        _pool[_active] = p;
        continue;
      }
      final isSpark = p.kind == ParticleKind.spark;
      final drag = max(0.0, 1 - (isSpark ? sparkDrag : smokeDrag) * dt);
      if (isSpark) p.vy += sparkGravity * dt;
      p.size += p.growth * dt;
      p.vx *= drag;
      p.vy *= drag;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      i++;
    }
  }

  /// Expires everything at once.
  void clear() => _active = 0;
}
