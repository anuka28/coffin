import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/widget_generators.dart';

const int _numRuns = 300;
final RunCounter _rangeCounter = RunCounter();
final RunCounter _loopCounter = RunCounter();
const int _safeNumRuns = 200;
const int _sampleMs = 10;
const int _windowSteps = 100;
final RunCounter _safeCounter = RunCounter();

void main() {
  group('FlickerSchedule property', () {
    _rangeCounter.reset();

    // Feature: spooky-widgets, Property 4: Flicker opacity stays in range
    // Validates: Requirements 8.3, 8.4, 8.11
    Glados2(anySeed, anyElapsed, ExploreConfig(numRuns: _numRuns)).test(
      'opacity is finite, within 0.75 to 1.0 and every level is a whole percent',
      (seed, elapsed) {
        _rangeCounter.increment();
        final FlickerSchedule schedule = FlickerSchedule(seed);
        final String why = 'seed=$seed elapsed=$elapsed';

        final double v = schedule.opacityAt(elapsed);
        expect(v.isFinite, isTrue, reason: why);
        expect(v >= 0.75 && v <= 1.0, isTrue, reason: '$why v=$v');

        final List<double> levels = schedule.levels;
        expect(levels.length, FlickerSchedule.levelCount, reason: why);
        for (final double level in levels) {
          final int p = (level * 100).round();
          expect(p >= 75 && p <= 100, isTrue, reason: '$why level=$level');
          // The lib builds each level as an integer percent divided by 100.
          expect(level, p / 100, reason: '$why level=$level');
        }
      },
    );

    test('ran every requested run', () {
      expect(_rangeCounter.runs > 0 && _rangeCounter.runs == _numRuns, isTrue);
    });

    _loopCounter.reset();

    // Feature: spooky-widgets, Property 5: Flicker is deterministic and loops
    // Validates: Requirements 8.5, 8.6
    Glados2(anySeed, anyElapsed, ExploreConfig(numRuns: _numRuns)).test(
      'same seed gives the same schedule and opacity repeats every loop',
      (seed, elapsed) {
        _loopCounter.increment();
        final FlickerSchedule a = FlickerSchedule(seed);
        final FlickerSchedule b = FlickerSchedule(seed);
        final String why = 'seed=$seed elapsed=$elapsed';

        expect(a.levels, b.levels, reason: why);
        expect(a.opacityAt(elapsed), b.opacityAt(elapsed), reason: why);
        expect(
          a.opacityAt(elapsed),
          a.opacityAt(elapsed + FlickerSchedule.loopMs),
          reason: why,
        );
      },
    );

    test('ran every requested run for the loop property', () {
      expect(_loopCounter.runs > 0 && _loopCounter.runs == _numRuns, isTrue);
    });

    _safeCounter.reset();

    // Feature: spooky-widgets, Property 6: Flicker is safe to look at
    // Validates: Requirements 8.7, 8.8, 8.9
    Glados(anySeed, ExploreConfig(numRuns: _safeNumRuns)).test(
      'at most 3 extrema per second, small level steps, dips and returns to 1.0',
      (seed) {
        _safeCounter.increment();
        final FlickerSchedule schedule = FlickerSchedule(seed);
        final String why = 'seed=$seed';

        final int n = FlickerSchedule.loopMs ~/ _sampleMs;
        final List<double> samples = <double>[
          for (int i = 0; i < n; i++) schedule.opacityAt(i * _sampleMs),
        ];
        // Wrap: sample n is sample 0 of the next loop.
        expect(schedule.opacityAt(n * _sampleMs), samples.first, reason: why);

        // Neighboring levels, including the wrap from the last to the first.
        final List<double> levels = schedule.levels;
        for (int i = 0; i < levels.length; i++) {
          final double step = (levels[(i + 1) % levels.length] - levels[i])
              .abs();
          expect(step <= 0.25 + 1e-9, isTrue, reason: '$why level=$i $step');
        }

        expect(levels.any((double l) => l <= 0.90), isTrue, reason: why);
        expect(levels.any((double l) => l == 1.0), isTrue, reason: why);
        expect(samples.any((double v) => v <= 0.90), isTrue, reason: why);
        expect(samples.any((double v) => v == 1.0), isTrue, reason: why);

        // Differences between neighboring samples, wrapping at the loop end.
        final List<double> diffs = <double>[
          for (int i = 0; i < n; i++) samples[(i + 1) % n] - samples[i],
        ];

        // Local extremum: a direction change in the sequence of non-zero
        // differences. Zero differences (plateaus) are skipped. The design
        // does not define plateau handling, so this definition is used.
        // Every window of 100 consecutive steps (1000 ms) is checked,
        // starting at every sample and wrapping.
        for (int start = 0; start < n; start++) {
          int extrema = 0;
          double previous = 0;
          for (int k = 0; k < _windowSteps; k++) {
            final double d = diffs[(start + k) % n];
            if (d == 0) continue;
            if (previous != 0 && (d > 0) != (previous > 0)) extrema++;
            previous = d;
          }
          expect(
            extrema <= 3,
            isTrue,
            reason: '$why windowStart=${start * _sampleMs}ms extrema=$extrema',
          );
        }
      },
    );

    test('ran every requested run for the safety property', () {
      expect(
        _safeCounter.runs > 0 && _safeCounter.runs == _safeNumRuns,
        isTrue,
      );
    });
  });
}
