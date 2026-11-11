import 'dart:math';

import 'package:apexblocks/ui/effects/particle_system.dart';
import 'package:flutter_test/flutter_test.dart';

ParticleSystem make({int capacity = maxParticles}) =>
    ParticleSystem(capacity: capacity, random: Random(7));

int burst(ParticleSystem s, [double x = 50, double y = 50]) =>
    s.burstCell(x, y, 40, sparkColor: 0xFFFFFFFF, smokeColor: 0xFF8A9099);

void main() {
  test('spawns sparks and smoke per cleared cell', () {
    final s = make();
    expect(burst(s), sparksPerCell + smokePerCell);
    expect(s.activeCount, sparksPerCell + smokePerCell);
    final kinds = [for (var i = 0; i < s.activeCount; i++) s.at(i).kind];
    expect(kinds.where((k) => k == ParticleKind.spark).length, sparksPerCell);
    expect(kinds.where((k) => k == ParticleKind.smoke).length, smokePerCell);

    for (var i = 0; i < 15; i++) {
      burst(s);
    }
    expect(s.activeCount, 16 * (sparksPerCell + smokePerCell));
  });

  test('never exceeds the particle cap', () {
    final s = make();
    expect(s.capacity, maxParticles);
    var spawned = 0;
    for (var i = 0; i < 64; i++) {
      spawned += burst(s);
    }
    expect(s.activeCount, maxParticles);
    expect(spawned, maxParticles);
    // Further spawns are dropped, not queued.
    expect(burst(s), 0);
    expect(
      s.spawnSpark(x: 0, y: 0, vx: 0, vy: 0, life: 1, size: 1, color: 0),
      isFalse,
    );
    expect(s.activeCount, maxParticles);
  });

  test('particles expire after their lifetime', () {
    final s = make();
    burst(s);
    s.update(sparkLifeMin * 0.5);
    expect(s.activeCount, sparksPerCell + smokePerCell);
    s.update(0.01);
    expect(s.activeCount, greaterThan(0));
    s.update(smokeLifeMax + sparkLifeMax);
    expect(s.activeCount, 0);
  });

  test('expiring one particle leaves the others updated exactly once', () {
    final s = make();
    s.spawnSpark(x: 0, y: 0, vx: 0, vy: 0, life: 0.1, size: 1, color: 0);
    s.spawnSpark(x: 0, y: 0, vx: 0, vy: 0, life: 1.0, size: 1, color: 0);
    s.spawnSpark(x: 0, y: 0, vx: 0, vy: 0, life: 0.5, size: 1, color: 0);
    s.update(0.2);
    expect(s.activeCount, 2);
    final lives = [s.at(0).life, s.at(1).life]..sort();
    expect(lives[0], closeTo(0.3, 1e-9));
    expect(lives[1], closeTo(0.8, 1e-9));
  });

  test('sparks fly out and fall; smoke rises and grows', () {
    final s = make();
    s.spawnSpark(x: 0, y: 0, vx: 100, vy: 0, life: 1, size: 2, color: 0);
    s.spawnSmoke(
      x: 0,
      y: 0,
      vx: 0,
      vy: -smokeRise,
      life: 1,
      size: 10,
      growth: 20,
      color: 0,
    );
    s.update(0.1);
    final spark = s.at(0);
    final smoke = s.at(1);
    expect(spark.x, greaterThan(0));
    expect(spark.x, lessThan(100 * 0.1)); // drag slows it a little
    expect(spark.vy, greaterThan(0)); // gravity pulls down (+y)
    expect(spark.y, greaterThan(0));
    expect(smoke.y, lessThan(0)); // drifts up
    expect(smoke.size, closeTo(12, 1e-9));
    expect(smoke.lifeFraction, closeTo(0.9, 1e-9));
  });

  test('a long frame step cannot make particles go backwards', () {
    final s = make();
    s.spawnSpark(x: 0, y: 0, vx: 100, vy: 0, life: 5, size: 1, color: 0);
    s.update(2); // drag factor would be negative without the clamp
    expect(s.at(0).vx, greaterThanOrEqualTo(0));
  });

  test('the pool is reused: no new particles are ever created', () {
    final s = make(capacity: 30);
    while (burst(s) > 0) {}
    final all = {for (var i = 0; i < s.activeCount; i++) s.at(i)};
    expect(all.length, 30);

    s.update(2); // everything expires
    expect(s.activeCount, 0);

    while (burst(s) > 0) {}
    final again = {for (var i = 0; i < s.activeCount; i++) s.at(i)};
    expect(again, all); // the very same objects
  });

  test('clear() empties the system', () {
    final s = make();
    burst(s);
    s.clear();
    expect(s.activeCount, 0);
  });
}
