import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:coffin_core/src/widgets/math/fog_field.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/widget_generators.dart';

const int _numRuns = 300;
const int _two32 = 4294967296;
const int _fogCount = 24;
const int _fogLaterMs = 123456;
const List<int> _flickerTimes = <int>[0, 200, 6399];
final RunCounter _counter = RunCounter();

/// The masked seed, computed with exact integer arithmetic and no bit
/// operators. Dart's `%` is non-negative for a positive divisor.
int _expectedMasked(int seed) => seed % _two32;

void _expectSameResults(int seed) {
  final int masked = _expectedMasked(seed);
  final String why = 'seed=$seed masked=$masked';

  // N4: the lib's masking operation agrees with exact arithmetic.
  expect(seed & 0xFFFFFFFF, masked, reason: why);

  final FlickerSchedule fromSeed = FlickerSchedule(seed);
  final FlickerSchedule fromMasked = FlickerSchedule(masked);
  expect(fromSeed.seed, masked, reason: why);
  expect(fromMasked.seed, masked, reason: why);
  expect(fromSeed.levels, fromMasked.levels, reason: why);
  for (final int t in _flickerTimes) {
    expect(fromSeed.opacityAt(t), fromMasked.opacityAt(t), reason: '$why t=$t');
  }

  final FogField fogFromSeed = FogField(seed: seed, count: _fogCount);
  final FogField fogFromMasked = FogField(seed: masked, count: _fogCount);
  expect(fogFromSeed.seed, masked, reason: why);
  expect(fogFromMasked.seed, masked, reason: why);
  expect(fogFromSeed.count, fogFromMasked.count, reason: why);
  expect(fogFromSeed.particlesAt(0), fogFromMasked.particlesAt(0), reason: why);
  expect(
    fogFromSeed.particlesAt(_fogLaterMs),
    fogFromMasked.particlesAt(_fogLaterMs),
    reason: why,
  );
  expect(
    fogFromSeed.staticParticles,
    fogFromMasked.staticParticles,
    reason: why,
  );
}

void main() {
  group('Seed masking property', () {
    _counter.reset();

    // Feature: spooky-widgets, Property 10: Seed masking
    // Validates: Requirements 10.3
    Glados(anyWideInt, ExploreConfig(numRuns: _numRuns)).test(
      'FlickerSchedule and FogField give the same results for a seed and its '
      'masked seed',
      (seed) {
        _counter.increment();
        _expectSameResults(seed);
      },
    );

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });

    test('edge-value seeds give the same results as their masked seeds', () {
      final List<int> seeds = <int>[
        -1,
        -2147483648,
        2147483647,
        2147483648,
        _two32 - 1,
        _two32,
        _two32 + 1,
        1099511627776,
        -1099511627776,
      ];
      for (final int seed in seeds) {
        _expectSameResults(seed);
      }
    });
  });
}
