import 'package:coffin_core/src/widgets/math/mood_bob.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import '../support/mood_chain.dart';
import '../support/mood_generators.dart';
import '../support/widget_generators.dart' show RunCounter, anyElapsed, anySize;

const int _numRuns = 200;
final RunCounter _counter = RunCounter();

/// Clamps a size into 24 to 256, with NaN as 64, as the loader does.
double _loaderSize(double size) {
  if (size.isNaN) {
    return 64;
  }
  return size < 24 ? 24 : (size > 256 ? 256 : size);
}

void main() {
  group('MoodTraits.reserveFor property', () {
    _counter.reset();

    // Feature: ghost-moods, Property 10: The reserved box covers every reachable pose
    // Validates: Requirements 6.2, 6.4
    Glados3(
      anySize,
      anyChain,
      anyElapsed,
      ExploreConfig(numRuns: _numRuns),
    ).test('the reserved box covers every reachable pose', (
      rawSize,
      chain,
      elapsed,
    ) {
      _counter.increment();
      final double size = _loaderSize(rawSize);
      final MoodPose pose = applyChain(chain);
      final double bob = MoodBob.mixedOffsetAt(pose, elapsed).abs();
      final int reserve = MoodTraits.reserveFor(size);
      final String why = 'size=$size chain=$chain elapsed=$elapsed pose=$pose';

      expect(bob.isFinite, isTrue, reason: 'bob finite: $why');
      expect(
        pose.upwardReach(size) + bob,
        lessThanOrEqualTo(reserve),
        reason: 'upward: $why',
      );
      expect(
        pose.downwardReach(size) + bob,
        lessThanOrEqualTo(reserve),
        reason: 'downward: $why',
      );
      expect(
        pose.horizontalReach(size),
        lessThanOrEqualTo(size / 2),
        reason: 'horizontal: $why',
      );
    });

    test('ran every requested run', () {
      expect(_counter.runs > 0 && _counter.runs == _numRuns, isTrue);
    });
  });
}
