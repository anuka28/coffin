import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestFailure, expect, group, isA, isNull, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';

const int _numRuns = 300;

/// A key that no generator in `ai_generators.dart` produces. Generated keys
/// are the four known keys, the empty key and `extra_0` to `extra_4`.
const String _absentKey = 'absent_key_for_property_13';

/// A value that no generated fact equals. Generated strings are built from at
/// most six short pieces, so none can equal this longer text, and it is not a
/// number, so `==` and the NaN rule both report it unequal to any number,
/// bool, null, list or map.
const String _foreignValue = 'a value no generator can produce, 13';

/// A copy of [source] with its entries inserted in an order shuffled from
/// [shuffleSeed]. Values are shared, only the insertion order changes.
Map<String, Object?> _shuffledCopy(
  Map<String, Object?> source,
  int shuffleSeed,
) {
  final List<MapEntry<String, Object?>> entries = source.entries.toList();
  final math.Random random = math.Random(shuffleSeed);
  for (int i = entries.length - 1; i > 0; i--) {
    final int j = random.nextInt(i + 1);
    final MapEntry<String, Object?> tmp = entries[i];
    entries[i] = entries[j];
    entries[j] = tmp;
  }
  final Map<String, Object?> copy = <String, Object?>{};
  for (final MapEntry<String, Object?> e in entries) {
    copy[e.key] = e.value;
  }
  return copy;
}

AiRequest _rebuild(
  AiRequest r, {
  AiPurpose? purpose,
  Map<String, Object?>? facts,
  int? maxLength,
  int? seed,
}) => AiRequest(
  purpose: purpose ?? r.purpose,
  facts: facts ?? r.facts,
  maxLength: maxLength ?? r.maxLength,
  seed: seed ?? r.seed,
);

/// Requests that differ from [r] in exactly one of the four fields, each
/// unequal to [r] under the request's own equality rule.
///
/// Facts compare with `==` or both NaN, so `5` equals `5.0` and NaN equals
/// NaN. A changed value therefore cannot be "5 to 5.0" or "NaN to NaN". The
/// changes used are a key that is absent from [r], and (when there is an
/// entry) one value replaced by [_foreignValue]. Neither can be equal under
/// the rule. Dropping a key is also unequal because the sizes differ.
Map<String, AiRequest> _oneFieldChanged(AiRequest r) {
  final AiPurpose otherPurpose = AiPurpose(
    r.purpose.id == 'zz_other_purpose'
        ? 'zz_another_purpose'
        : 'zz_other_purpose',
  );
  final Map<String, AiRequest> changed = <String, AiRequest>{
    'purpose': _rebuild(r, purpose: otherPurpose),
    'maxLength': _rebuild(r, maxLength: r.maxLength + 1),
    'seed': _rebuild(
      r,
      seed: r.seed < AiRequest.maxSeed ? r.seed + 1 : r.seed - 1,
    ),
    'facts (key added)': _rebuild(
      r,
      facts: <String, Object?>{...r.facts, _absentKey: 1},
    ),
  };
  if (r.facts.isNotEmpty) {
    final String firstKey = r.facts.keys.first;
    changed['facts (value changed)'] = _rebuild(
      r,
      facts: <String, Object?>{...r.facts, firstKey: _foreignValue},
    );
    changed['facts (key removed)'] = _rebuild(
      r,
      facts: <String, Object?>{...r.facts}..remove(firstKey),
    );
  }
  return changed;
}

void _check(AiRequest r, int shuffleSeed) {
  // Same four fields, facts inserted in another order.
  final AiRequest same = AiRequest(
    purpose: r.purpose,
    facts: _shuffledCopy(r.facts, shuffleSeed),
    maxLength: r.maxLength,
    seed: r.seed,
  );
  expect(same, equals(r), reason: 'shuffled copy not equal');
  expect(r, equals(same), reason: 'equality not symmetric');
  expect(same.hashCode, r.hashCode, reason: 'shuffled copy hash differs');

  // Changing any one field gives an unequal request.
  _oneFieldChanged(r).forEach((String what, AiRequest other) {
    expect(other == r, isFalse, reason: 'changed $what is equal to r');
    expect(r == other, isFalse, reason: 'changed $what: not symmetric');
  });

  // Mutating the source map afterwards changes nothing.
  final Map<String, Object?> source = <String, Object?>{...r.facts};
  final AiRequest built = AiRequest(
    purpose: r.purpose,
    facts: source,
    maxLength: r.maxLength,
    seed: r.seed,
  );
  final int hashBefore = built.hashCode;
  source[_absentKey] = 2;
  if (source.length > 1) source.remove(source.keys.first);
  source.clear();
  source['late_key'] = 3;
  expect(built, equals(r), reason: 'source mutation changed the request');
  expect(built.hashCode, hashBefore, reason: 'source mutation changed hash');
  expect(built.facts.length, r.facts.length, reason: 'facts size changed');
}

const int _maxSafe = 9007199254740991; // 2^53 - 1

/// Values around 16, around 0 and up to 2^53 - 1, for `maxLength`.
final Generator<int> _anyBoundaryMaxLength = () {
  final Generator<int> around = anyIntBetween(-1000, 1001);
  final Generator<int> near16 = anyIntBetween(14, 19);
  final Generator<int> offset = anyIntBetween(0, 4294967296);
  const List<int> edges = <int>[
    -1,
    0,
    15,
    16,
    17,
    4294967295,
    4294967296,
    _maxSafe,
  ];
  return any.simple<int>(
    generate: (math.Random random, int size) {
      switch (random.nextInt(5)) {
        case 0:
          return around(random, size).value;
        case 1:
          return near16(random, size).value;
        case 2:
          return edges[random.nextInt(edges.length)];
        case 3:
          return _maxSafe - offset(random, size).value;
        default:
          return -_maxSafe + offset(random, size).value;
      }
    },
    shrink: (int v) => v == 16 ? const <int>[] : <int>[16 + (v - 16) ~/ 2],
  );
}();

/// Values around 0 and 4294967295, large negatives and large positives below
/// 2^53, for `seed`.
final Generator<int> _anyBoundarySeed = () {
  final Generator<int> near0 = anyIntBetween(-2, 3);
  final Generator<int> nearMax = anyIntBetween(4294967293, 4294967298);
  final Generator<int> offset = anyIntBetween(0, 4294967296);
  const List<int> edges = <int>[
    -2,
    -1,
    0,
    1,
    4294967294,
    4294967295,
    4294967296,
    -4294967296,
    _maxSafe,
    -_maxSafe,
  ];
  return any.simple<int>(
    generate: (math.Random random, int size) {
      switch (random.nextInt(6)) {
        case 0:
          return near0(random, size).value;
        case 1:
          return nearMax(random, size).value;
        case 2:
          return edges[random.nextInt(edges.length)];
        case 3:
          return -offset(random, size).value - 1;
        case 4:
          return _maxSafe - offset(random, size).value;
        default:
          return 4294967296 + offset(random, size).value;
      }
    },
    shrink: (int v) => v == 0 ? const <int>[] : <int>[v ~/ 2],
  );
}();

final RunCounter _requestValidationRuns = RunCounter();

void _checkValidation(int maxLength, int seed) {
  // The rule text: invalid when maxLength < 16, seed < 0 or seed > 4294967295.
  final bool invalid = maxLength < 16 || seed < 0 || seed > 4294967295;
  AiRequest? built;
  Object? thrown;
  try {
    built = AiRequest(
      purpose: AiPurpose('zz_other_purpose'),
      maxLength: maxLength,
      seed: seed,
    );
  } catch (e) {
    thrown = e;
  }
  if (invalid) {
    expect(thrown, isA<ArgumentError>(), reason: 'expected ArgumentError');
    expect(built, isNull, reason: 'a request was built');
  } else {
    expect(thrown, isNull, reason: 'unexpected throw: $thrown');
    expect(built!.maxLength, maxLength, reason: 'maxLength not held');
    expect(built.seed, seed, reason: 'seed not held');
  }
}

final RunCounter _requestEqualityRuns = RunCounter();

void main() {
  group('AiRequest property: equality and hash', () {
    // Feature: coffin-ai, Property 13: Request equality and hash
    // Validates: Requirements 2.1, 2.8, 2.9
    Glados2(
      anyAiRequest,
      anyIntBetween(0, 4294967296),
      ExploreConfig(numRuns: _numRuns),
    ).test('equal when only the fact order differs, unequal when a field '
        'changes, immune to source mutation', (AiRequest r, int shuffleSeed) {
      _requestEqualityRuns.increment();
      try {
        _check(r, shuffleSeed);
      } on TestFailure catch (e) {
        throw TestFailure(
          '${e.message}\ninput: ${describeRequest(r)} shuffleSeed=$shuffleSeed',
        );
      }
    });

    test('ran the full number of runs', () {
      expect(_requestEqualityRuns.runs, greaterThan(0));
      expect(_requestEqualityRuns.runs, _numRuns);
    });
  });

  group('AiRequest property: validation boundaries', () {
    // Feature: coffin-ai, Property 14: Request validation boundaries
    // Validates: Requirements 2.5, 2.6
    Glados2(
      _anyBoundaryMaxLength,
      _anyBoundarySeed,
      ExploreConfig(numRuns: _numRuns),
    ).test('throws ArgumentError exactly when maxLength < 16 or seed is '
        'outside 0 to 4294967295', (int maxLength, int seed) {
      _requestValidationRuns.increment();
      try {
        _checkValidation(maxLength, seed);
      } on TestFailure catch (e) {
        throw TestFailure(
          '${e.message}\ninput: maxLength=$maxLength seed=$seed',
        );
      }
    });

    test('ran the full number of runs', () {
      expect(_requestValidationRuns.runs, greaterThan(0));
      expect(_requestValidationRuns.runs, _numRuns);
    });
  });
}
