import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart' show expect, equals, isPositive;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/name_rules.dart';

// Pure support code: no dart:io. It also runs in Chrome. Every generated
// integer stays far below 2^53.

/// Integers from [min] inclusive to [max] exclusive.
///
/// Use this instead of `any.intInRange`: glados 1.1.7 computes `1 << 32` in
/// its range helper, which is 0 on web. This one calls `Random.nextInt`
/// directly, which works on every platform for ranges below 2^32. Shrinks
/// towards [min] (or 0 when 0 is in range).
Generator<int> anyIntBetween(int min, int max) {
  assert(min < max && max - min <= 0xFFFFFFFF);
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
/// The web-safe counterpart of `any.listWithLengthInRange`. Shrinks by
/// dropping and shrinking elements.
Generator<List<T>> anyListBetween<T>(int min, int max, Generator<T> item) {
  assert(0 <= min && min < max);
  return (math.Random random, int size) {
    final int length = min + random.nextInt(max - min);
    return ShrinkableList<T>(<Shrinkable<T>>[
      for (int i = 0; i < length; i++) item(random, size),
    ], min);
  };
}

/// Counts the runs of a property body. Increment it in the body, then call
/// [expectRuns] in a plain test so a silent skip cannot pass.
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

  /// Asserts that at least one run happened and that [runs] equals [numRuns].
  void expectRuns(int numRuns) {
    expect(_runs, isPositive, reason: 'the property body never ran');
    expect(_runs, equals(numRuns), reason: 'run count differs from numRuns');
  }
}

/// First epoch day the generator draws from: 2000-01-01.
const int firstGeneratedEpochDay = 10957;

/// Last epoch day the generator draws from: 2099-12-31.
const int lastGeneratedEpochDay = 47482;

/// Days that sit on calendar edges: leap days, month and year ends, and the
/// daylight saving changes of 2026 in the northern hemisphere.
final List<LocalDay> edgeLocalDays = <LocalDay>[
  LocalDay(2000, 1, 1),
  LocalDay(2000, 2, 29),
  LocalDay(2000, 12, 31),
  LocalDay(2024, 2, 28),
  LocalDay(2024, 2, 29),
  LocalDay(2024, 3, 1),
  LocalDay(2025, 2, 28),
  LocalDay(2025, 3, 1),
  LocalDay(2026, 1, 31),
  LocalDay(2026, 2, 28),
  LocalDay(2026, 3, 8),
  LocalDay(2026, 3, 29),
  LocalDay(2026, 4, 30),
  LocalDay(2026, 10, 25),
  LocalDay(2026, 11, 1),
  LocalDay(2026, 12, 31),
  LocalDay(2027, 1, 1),
  LocalDay(2096, 2, 29),
  LocalDay(2099, 12, 31),
];

/// Generates a [LocalDay] from 2000-01-01 to 2099-12-31, with the days in
/// [edgeLocalDays] about one time in four. Shrinks towards 2000-01-01.
Generator<LocalDay> get anyLocalDay => any.simple<LocalDay>(
  generate: (math.Random random, int size) {
    if (random.nextInt(4) == 0) {
      return edgeLocalDays[random.nextInt(edgeLocalDays.length)];
    }
    return LocalDay.fromEpochDay(
      firstGeneratedEpochDay +
          random.nextInt(lastGeneratedEpochDay - firstGeneratedEpochDay + 1),
    );
  },
  shrink: (LocalDay d) sync* {
    final int e = d.epochDay;
    if (e > firstGeneratedEpochDay) {
      yield LocalDay.fromEpochDay(
        firstGeneratedEpochDay + (e - firstGeneratedEpochDay) ~/ 2,
      );
    }
  },
);

/// Generates habit names: valid (1 to 40 code points, padded or not),
/// over-40 (41 to 60 code points) and whitespace-only (empty included).
///
/// About 60% valid, 20% too long, 20% blank. Shrinks towards `'a'`.
Generator<String> get anyHabitName => any.simple<String>(
  generate: (math.Random random, int size) {
    final int roll = random.nextInt(10);
    if (roll < 6) {
      final int length = random.nextBool()
          ? <int>[1, 2, NameRules.maxLength][random.nextInt(3)]
          : 1 + random.nextInt(NameRules.maxLength);
      return _pad(random, _word(random, length));
    }
    if (roll < 8) {
      final int length = NameRules.maxLength + 1 + random.nextInt(20);
      return _pad(random, _word(random, length));
    }
    final int blanks = random.nextInt(6);
    return <String>[
      for (int i = 0; i < blanks; i++) _blanks[random.nextInt(_blanks.length)],
    ].join();
  },
  shrink: (String s) => s == 'a' ? const <String>[] : const <String>['a'],
);

const List<String> _letters = <String>[
  'a', 'b', 'Z', '7', 'é', 'ß', '漢', '\u{1F47B}', '-', '!', //
];

const List<String> _blanks = <String>[' ', '\t', '\n', '\u00A0', '\u2003'];

String _word(math.Random random, int length) => <String>[
  for (int i = 0; i < length; i++) _letters[random.nextInt(_letters.length)],
].join();

/// Surrounds [core] with blanks half of the time. [core] starts and ends with
/// a letter, so trimming it leaves the same code point count.
String _pad(math.Random random, String core) {
  if (random.nextBool()) return core;
  final String lead = _blanks[random.nextInt(_blanks.length)];
  final String trail = _blanks[random.nextInt(_blanks.length)];
  return '$lead$core$trail';
}

/// Health values at the edges of the bands.
const List<int> healthEdges = <int>[0, 1, 24, 25, 49, 50, 79, 80, 100];

/// Generates a Health from 0 to 100, with the band edges in [healthEdges]
/// about half of the time. Shrinks towards 0.
Generator<int> get anyHealth => any.simple<int>(
  generate: (math.Random random, int size) => random.nextBool()
      ? healthEdges[random.nextInt(healthEdges.length)]
      : random.nextInt(101),
  shrink: (int v) => v == 0 ? const <int>[] : <int>[v ~/ 2],
);
