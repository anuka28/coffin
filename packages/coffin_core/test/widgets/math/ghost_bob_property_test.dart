import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/widget_generators.dart';

const int _numRuns = 300;
final RunCounter _rangeCounter = RunCounter();
final RunCounter _smoothCounter = RunCounter();

void main() {
  group('GhostBob property', () {
    _rangeCounter.reset();

    // Feature: spooky-widgets, Property 2: Bob stays in range and loops
    // Validates: Requirements 7.2, 7.3, 7.4, 7.7
    Glados3(
      anyIntBetween(-100, 10001),
      anyAmplitude,
      anyElapsed,
      ExploreConfig(numRuns: _numRuns),
    ).test('offset is finite, in range and repeats every period', (
      period,
      amplitude,
      elapsed,
    ) {
      _rangeCounter.increment();
      final GhostBob bob = GhostBob(periodMs: period, amplitude: amplitude);
      final int expectedPeriod = period < 2500
          ? 2500
          : (period > 5000 ? 5000 : period);
      final double expectedAmplitude = amplitude < 2
          ? 2.0
          : (amplitude > 10 ? 10.0 : amplitude);
      final String why = 'period=$period amplitude=$amplitude elapsed=$elapsed';

      expect(bob.periodMs, expectedPeriod, reason: why);
      expect(bob.amplitude, expectedAmplitude, reason: why);

      final double v = bob.offsetAt(elapsed);
      expect(v.isFinite, isTrue, reason: why);
      expect(
        v,
        inInclusiveRange(-expectedAmplitude, expectedAmplitude),
        reason: why,
      );
      expect(v, bob.offsetAt(elapsed + bob.periodMs), reason: 'loop: $why');
    });

    test('ran every requested run', () {
      expect(_rangeCounter.runs > 0 && _rangeCounter.runs == _numRuns, isTrue);
    });

    _smoothCounter.reset();

    // Feature: spooky-widgets, Property 3: Bob moves smoothly
    // Validates: Requirements 7.5, 7.7
    Glados3(
      anyIntBetween(-100, 10001),
      anyAmplitude,
      anyElapsed,
      ExploreConfig(numRuns: _numRuns),
    ).test('offset changes by a bounded step in 16 ms', (
      period,
      amplitude,
      elapsed,
    ) {
      _smoothCounter.increment();
      final GhostBob bob = GhostBob(periodMs: period, amplitude: amplitude);
      final double step = (bob.offsetAt(elapsed + 16) - bob.offsetAt(elapsed))
          .abs();
      final double bound = 6 * bob.amplitude * 16 / bob.periodMs + 1e-9;

      expect(
        step <= bound,
        isTrue,
        reason:
            'period=$period amplitude=$amplitude elapsed=$elapsed '
            'step=$step bound=$bound',
      );
    });

    test('ran every requested smoothness run', () {
      expect(
        _smoothCounter.runs > 0 && _smoothCounter.runs == _numRuns,
        isTrue,
      );
    });
  });
}
