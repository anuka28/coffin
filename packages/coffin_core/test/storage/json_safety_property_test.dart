import 'dart:math' as math_lib;

import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/json_safety.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

const int _numRuns = 200;

/// The first integer that is not exact on every platform: 2^53.
const int _beyondSafeInt = 9007199254740992;

/// Seeds that drive the shape of a generated safe map.
Generator<int> get _anySeed => any.intInRange(0, 1 << 30);

/// Doubles used as leaves. Always finite, built with `doubleInRange`.
Generator<List<double>> get _anyDoubles =>
    any.listWithLengthInRange(1, 6, any.doubleInRange(-1e6, 1e6));

/// One number that encodes the kind of unsafe value and where it goes.
Generator<int> get _anySelector => any.intInRange(0, 1 << 24);

int _safeRuns = 0;
int _unsafeRuns = 0;

/// Builds a safe value. Depth stays well below [JsonSafety.maxDepth].
Object? _safeValue(math_lib.Random rng, List<double> doubles, int depth) {
  final int choice = rng.nextInt(depth >= 4 ? 5 : 7);
  switch (choice) {
    case 0:
      return null;
    case 1:
      return rng.nextBool();
    case 2:
      return rng.nextInt(2000001) - 1000000;
    case 3:
      return doubles[rng.nextInt(doubles.length)];
    case 4:
      return 'text${rng.nextInt(100)}';
    case 5:
      return <Object?>[
        for (int i = 0; i < rng.nextInt(4); i++)
          _safeValue(rng, doubles, depth + 1),
      ];
    default:
      return _safeMap(rng, doubles, depth + 1);
  }
}

JsonMap _safeMap(math_lib.Random rng, List<double> doubles, int depth) {
  return <String, Object?>{
    for (int i = 0; i < rng.nextInt(4); i++)
      'k$i': _safeValue(rng, doubles, depth),
  };
}

/// A safe map; the root is always a map with at least one entry.
JsonMap _buildSafe(int seed, List<double> doubles) {
  final math_lib.Random rng = math_lib.Random(seed);
  final JsonMap map = _safeMap(rng, doubles, 1);
  map['first'] = _safeValue(rng, doubles, 1);
  return map;
}

/// Every Map and List reachable from [value], by identity.
void _collectContainers(Object? value, List<Object> out) {
  if (value is Map) {
    out.add(value);
    for (final Object? v in value.values) {
      _collectContainers(v, out);
    }
  } else if (value is List) {
    out.add(value);
    for (final Object? v in value) {
      _collectContainers(v, out);
    }
  }
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// An unsafe value for [kind], plus a label for failure messages.
(Object?, String) _unsafeValue(int kind, int pick) {
  switch (kind) {
    case 0:
      return (double.nan, 'NaN');
    case 1:
      return (
        pick.isEven ? double.infinity : double.negativeInfinity,
        'infinity',
      );
    case 2:
      return (
        pick.isEven ? _beyondSafeInt : -_beyondSafeInt,
        'integer beyond 2^53 - 1',
      );
    case 3:
      return (<Object?, Object?>{42: 'x'}, 'non-String map key');
    case 4:
      return (DateTime.utc(2024, 10, 31), 'DateTime');
    default:
      // 65 nested lists: deeper than 64 wherever it is inserted.
      Object? chain = <Object?>[];
      for (int i = 0; i < 65; i++) {
        chain = <Object?>[chain];
      }
      return (chain, 'depth beyond 64');
  }
}

void main() {
  group('JsonSafety property: safe maps', () {
    // Feature: crypt-storage, Property 4: JSON safety detects every unsafe value
    // Validates: Requirements 6.2, 6.6, 9.11
    Glados2(_anySeed, _anyDoubles, ExploreConfig(numRuns: _numRuns)).test(
      'check passes, deepCopy equals and shares no container',
      (seed, doubles) {
        _safeRuns++;
        final JsonMap original = _buildSafe(seed, doubles);
        final String why = 'seed=$seed doubles=$doubles map=$original';

        JsonSafety.check(original);
        final JsonMap copy = JsonSafety.deepCopy(original);

        expect(_deepEquals(copy, original), isTrue, reason: why);

        final List<Object> originalContainers = <Object>[];
        final List<Object> copyContainers = <Object>[];
        _collectContainers(original, originalContainers);
        _collectContainers(copy, copyContainers);
        final Set<Object> seen = Set<Object>.identity()
          ..addAll(originalContainers);
        for (final Object c in copyContainers) {
          expect(seen.contains(c), isFalse, reason: 'shared instance: $why');
        }
      },
    );

    test('the safe-map property body ran numRuns times', () {
      expect(_safeRuns, _numRuns);
    });
  });

  group('JsonSafety property: unsafe values', () {
    // Feature: crypt-storage, Property 4: JSON safety detects every unsafe value
    // Validates: Requirements 6.2, 6.6, 9.11
    Glados3(
      _anySeed,
      _anyDoubles,
      _anySelector,
      ExploreConfig(numRuns: _numRuns),
    ).test('one injected unsafe value makes check throw', (
      seed,
      doubles,
      selector,
    ) {
      final int kind = selector % 6;
      final int pick = selector ~/ 6;
      final int where = selector ~/ 36;
      _unsafeRuns++;
      final JsonMap map = _buildSafe(seed, doubles);
      final List<Object> containers = <Object>[];
      _collectContainers(map, containers);
      final Object target = containers[where % containers.length];

      final (Object? bad, String label) = _unsafeValue(kind, pick);
      if (target is Map) {
        target['bad'] = bad;
      } else {
        (target as List<Object?>).add(bad);
      }

      final String why = 'seed=$seed selector=$selector kind=$label';
      expect(() => JsonSafety.check(map), throwsArgumentError, reason: why);
      expect(() => JsonSafety.deepCopy(map), throwsArgumentError, reason: why);
    });

    test('the unsafe-value property body ran numRuns times', () {
      expect(_unsafeRuns, _numRuns);
    });
  });
}
