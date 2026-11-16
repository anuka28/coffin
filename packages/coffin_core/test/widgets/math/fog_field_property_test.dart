import 'package:coffin_core/src/common/seeded_random.dart';
import 'package:coffin_core/src/widgets/math/fog_disc.dart';
import 'package:coffin_core/src/widgets/math/fog_field.dart';
import 'package:coffin_core/src/widgets/math/fog_particle.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/widget_generators.dart';

const int _numRuns = 300;
final RunCounter _validCounter = RunCounter();
final RunCounter _boundsCounter = RunCounter();
final RunCounter _determinismCounter = RunCounter();

const List<double> _badDimensions = <double>[
  -1,
  -0.5,
  -4000,
  double.nan,
  double.infinity,
  double.negativeInfinity,
];

/// Radius, alpha and period of one particle, replayed from the draw order in
/// the design table.
typedef _Replayed = ({double radius, double alpha, int periodMs});

List<_Replayed> _replay(int seed, int count) {
  final SeededRandom r = SeededRandom(seed & 0xFFFFFFFF);
  final List<_Replayed> out = <_Replayed>[];
  for (int i = 0; i < count; i++) {
    r.nextInt(1001); // ax
    r.nextInt(1001); // ay
    r.nextInt(1001); // bx
    r.nextInt(1001); // by
    final double radius = (120 + r.nextInt(181)) / 1000;
    final double alpha = (30 + r.nextInt(21)) / 1000;
    final int periodMs = 30000 + 1000 * r.nextInt(61);
    r.nextUint32(); // startMs
    out.add((radius: radius, alpha: alpha, periodMs: periodMs));
  }
  return out;
}

void main() {
  group('FogField property', () {
    _validCounter.reset();
    _boundsCounter.reset();
    _determinismCounter.reset();

    // Feature: spooky-widgets, Property 7: Fog particles are valid
    // Validates: Requirements 9.1, 9.2, 9.3, 9.4
    Glados3(
      anySeed,
      anyCount,
      anyElapsed,
      ExploreConfig(numRuns: _numRuns),
    ).test('returns clamp(count, 0, 24) particles with unit positions, radius '
        '0.12 to 0.30 and alpha 0.03 to 0.05', (seed, count, elapsed) {
      _validCounter.increment();
      final String why = 'seed=$seed count=$count elapsed=$elapsed';
      final int expected = count < 0 ? 0 : (count > 24 ? 24 : count);

      final FogField field = FogField(seed: seed, count: count);
      final List<FogParticle> particles = field.particlesAt(elapsed);

      expect(field.count, expected, reason: why);
      expect(particles.length, expected, reason: why);
      for (final FogParticle p in particles) {
        final String at = '$why particle=$p';
        expect(p.x >= 0 && p.x <= 1, isTrue, reason: at);
        expect(p.y >= 0 && p.y <= 1, isTrue, reason: at);
        expect(p.radius >= 0.12 && p.radius <= 0.30, isTrue, reason: at);
        expect(p.alpha >= 0.03 && p.alpha <= 0.05, isTrue, reason: at);
      }
    });

    test('ran every requested run', () {
      expect(_validCounter.runs > 0 && _validCounter.runs == _numRuns, isTrue);
    });

    // Feature: spooky-widgets, Property 8: Pixel mapping stays inside the box
    // Validates: Requirements 9.9, 9.10, 6.9
    Glados3(
      any.combine3(
        anySeed,
        anyCount,
        anyElapsed,
        (int a, int b, int c) => (a, b, c),
      ),
      any.combine2(anySize, anySize, (double w, double h) => (w, h)),
      anyIntBetween(0, 18),
      ExploreConfig(numRuns: _numRuns),
    ).test('toBounds stays inside the box and treats bad dimensions as 0', (
      draw,
      dims,
      choice,
    ) {
      final (int seed, int count, int elapsed) = draw;
      final (double width, double height) = dims;
      _boundsCounter.increment();
      final String why =
          'seed=$seed count=$count elapsed=$elapsed width=$width '
          'height=$height choice=$choice';
      final double shorter = width < height ? width : height;

      final List<FogParticle> particles = FogField(
        seed: seed,
        count: count,
      ).particlesAt(elapsed);
      for (final FogParticle p in particles) {
        final FogDisc d = FogField.toBounds(p, width, height);
        final String at = '$why particle=$p disc=$d';
        expect(d.x >= 0 && d.x <= width, isTrue, reason: at);
        expect(d.y >= 0 && d.y <= height, isTrue, reason: at);
        expect(d.radius >= 0 && d.radius <= shorter, isTrue, reason: at);
      }

      // choice 0..5 breaks the width, 6..11 the height, 12..17 both.
      final double bad = _badDimensions[choice % 6];
      final int mode = choice ~/ 6;
      final double badW = mode == 1 ? width : bad;
      final double badH = mode == 0 ? height : bad;
      final double zeroW = mode == 1 ? width : 0;
      final double zeroH = mode == 0 ? height : 0;
      for (final FogParticle p in particles) {
        final FogDisc got = FogField.toBounds(p, badW, badH);
        final FogDisc want = FogField.toBounds(p, zeroW, zeroH);
        expect(
          got == want,
          isTrue,
          reason: '$why bad=$bad got=$got want=$want',
        );
      }
    });

    test('ran every requested bounds run', () {
      expect(
        _boundsCounter.runs > 0 && _boundsCounter.runs == _numRuns,
        isTrue,
      );
    });

    // Feature: spooky-widgets, Property 9: Fog is deterministic, loops, and extends by prefix
    // Validates: Requirements 9.5, 9.7, 9.8, 9.11
    Glados2(
      any.combine3(
        anySeed,
        anyCount,
        anyElapsed,
        (int a, int b, int c) => (a, b, c),
      ),
      anyIntBetween(0, 30),
      ExploreConfig(numRuns: _numRuns),
    ).test('is deterministic, loops per particle and extends by prefix', (
      draw,
      extra,
    ) {
      final (int seed, int count, int elapsed) = draw;
      _determinismCounter.increment();
      final String why =
          'seed=$seed count=$count elapsed=$elapsed '
          'extra=$extra';

      // (a) two separately built fields agree.
      final FogField field = FogField(seed: seed, count: count);
      final List<FogParticle> now = field.particlesAt(elapsed);
      expect(
        FogField(seed: seed, count: count).particlesAt(elapsed),
        now,
        reason: why,
      );

      // (b) each particle repeats after its own period.
      final List<_Replayed> replay = _replay(seed, field.count);
      for (int i = 0; i < field.count; i++) {
        final String at = '$why particle=$i replay=${replay[i]}';
        expect(now[i].radius, replay[i].radius, reason: at);
        expect(now[i].alpha, replay[i].alpha, reason: at);
        final List<FogParticle> later = field.particlesAt(
          elapsed + replay[i].periodMs,
        );
        expect(later[i] == now[i], isTrue, reason: '$at later=${later[i]}');
      }

      // (c) a smaller field is the prefix of a larger one.
      final FogField larger = FogField(seed: seed, count: field.count + extra);
      final List<FogParticle> big = larger.particlesAt(elapsed);
      expect(big.length, larger.count, reason: why);
      expect(big.take(field.count).toList(), now, reason: why);
    });

    test('ran every requested determinism run', () {
      expect(
        _determinismCounter.runs > 0 && _determinismCounter.runs == _numRuns,
        isTrue,
      );
    });
  });
}
