import 'dart:math' as math;

import 'package:glados/glados.dart' hide expect, group, test;

// Pure support code: no dart:io, no hive_ce, no Flutter. It runs in Chrome.
//
// An independent copy of the helpers in `test/ai/support/ai_generators.dart`
// (tests never import across the two support folders). Only web-safe glados
// generators are used: `simple` and `combine2`. Every integer stays below 2^53.

/// Integers from [min] inclusive to [max] exclusive. The span may reach
/// 4294967296 (2^32), the full seed range.
///
/// Use this instead of `any.intInRange`, which computes `1 << 32` and throws
/// on web. `Random.nextInt` accepts a limit up to 2^32 on every platform.
/// Shrinks towards [min] (or 0 when 0 is in range).
Generator<int> anyIntBetween(int min, int max) {
  assert(min < max && max - min <= 4294967296);
  final int target = min <= 0 && max > 0 ? 0 : min;
  return any.simple<int>(
    generate: (math.Random random, int size) => min + random.nextInt(max - min),
    shrink: (int v) sync* {
      if (v > target) {
        yield target + (v - target) ~/ 2;
      } else if (v < target) {
        yield target - (target - v) ~/ 2;
      }
    },
  );
}

/// Lists of [item] with a length from [min] inclusive to [max] exclusive.
///
/// The web-safe counterpart of `any.listWithLengthInRange`.
Generator<List<T>> anyListBetween<T>(int min, int max, Generator<T> item) {
  assert(0 <= min && min < max);
  return (math.Random random, int size) {
    final int length = min + random.nextInt(max - min);
    return ShrinkableList<T>(<Shrinkable<T>>[
      for (int i = 0; i < length; i++) item(random, size),
    ], min);
  };
}

/// Counts the runs of a property body. Increment it in the body, then check
/// `runs > 0` and `runs == numRuns` in a plain test.
final class RunCounter {
  /// Creates a counter at zero.
  RunCounter();

  int _runs = 0;

  /// How many times [increment] was called.
  int get runs => _runs;

  /// Records one run.
  void increment() => _runs++;

  /// Sets the count back to zero.
  void reset() => _runs = 0;
}

/// 2^32, written out so no shift is needed.
const int _two32 = 4294967296;

/// 2^40, written out so no shift is needed.
const int _two40 = 1099511627776;

/// The seeds at the edges of the range and of the 2^31 boundary.
const List<int> edgeSeeds = <int>[0, 1, 42, 2147483647, 2147483648, 4294967295];

/// Periods in milliseconds worth hitting often as elapsed times: the smallest
/// periods, the GhostBob min, default and max (2500, 3600, 5000), the
/// FlickerSchedule step and loop (400, 6400) and the FogField period range
/// (30000, 60000, 90000).
const List<int> edgePeriods = <int>[
  1,
  2,
  400,
  2500,
  3600,
  5000,
  6400,
  30000,
  60000,
  90000,
];

/// Seeds from 0 to 4294967295, with [edgeSeeds] drawn about 20 percent of the
/// time. Shrinks towards 0.
Generator<int> get anySeed => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(5) == 0
      ? edgeSeeds[random.nextInt(edgeSeeds.length)]
      : random.nextInt(_two32),
  shrink: _halveTowardsZero,
);

/// Integers from minus 2^40 to 2^40 inclusive. Shrinks towards 0.
///
/// A single `nextInt` cannot span 2^41 values, so the value is the sum of a
/// 9-bit high part (times 2^32) and a 32-bit low part. The sum stays below
/// 2^41, far under 2^53.
Generator<int> get anyWideInt => any.simple<int>(
  generate: (math.Random random, int size) => _wide(random),
  shrink: _halveTowardsZero,
);

int _wide(math.Random random) {
  if (random.nextInt(50) == 0) {
    return random.nextBool() ? _two40 : -_two40;
  }
  return random.nextInt(512) * _two32 + random.nextInt(_two32) - _two40;
}

/// Elapsed times from minus 2^40 to 2^40, with 0, 1, -1 and the
/// [edgePeriods] (and their negatives) drawn about 20 percent of the time.
/// Shrinks towards 0.
Generator<int> get anyElapsed => any.simple<int>(
  generate: (math.Random random, int size) {
    if (random.nextInt(5) == 0) {
      final List<int> edges = <int>[
        0,
        1,
        -1,
        ...edgePeriods,
        ...edgePeriods.map((int p) => -p),
      ];
      return edges[random.nextInt(edges.length)];
    }
    return _wide(random);
  },
  shrink: _halveTowardsZero,
);

/// Counts from -5 to 40 inclusive, so negatives and values above 24 occur.
/// Shrinks towards 0.
Generator<int> get anyCount => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(46) - 5,
  shrink: _halveTowardsZero,
);

/// Sizes from 0 to 4000, built from integer thousandths, with the fixed edge
/// values 0, 0.5 and 1 drawn about 20 percent of the time. Shrinks towards 0.
Generator<double> get anySize => any.simple<double>(
  generate: (math.Random random, int size) {
    if (random.nextInt(5) == 0) {
      return const <double>[0, 0.5, 1][random.nextInt(3)];
    }
    return random.nextInt(4000001) / 1000;
  },
  shrink: (double v) sync* {
    if (v > 0) {
      yield (v * 1000).round() ~/ 2 / 1000;
    }
  },
);

/// Amplitudes from -5 to 40, built from integer thousandths. Shrinks towards
/// 0.
Generator<double> get anyAmplitude => any.simple<double>(
  generate: (math.Random random, int size) =>
      (random.nextInt(45001) - 5000) / 1000,
  shrink: (double v) sync* {
    final int thousandths = (v * 1000).round();
    if (thousandths != 0) {
      yield (thousandths ~/ 2) / 1000;
    }
  },
);

Iterable<int> _halveTowardsZero(int v) sync* {
  if (v != 0) {
    yield v ~/ 2;
  }
}
