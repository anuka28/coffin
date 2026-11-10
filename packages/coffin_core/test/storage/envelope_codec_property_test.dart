import 'package:coffin_core/src/storage/envelope.dart';
import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/json_map.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, group, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;

// This file runs on the VM and on Chrome: no dart:io, no hive_ce, no
// @TestOn('vm').

const int _numRuns = 200;

/// 2^53 - 1, the largest integer magnitude JSON-safe maps may hold.
const int _maxSafeInt = 9007199254740991;

/// Pieces that strings and keys are glued from: ASCII, accented letters, CJK,
/// an emoji (a valid surrogate pair), lone surrogates, quotes, backslashes,
/// slashes, control characters and the JSON-sensitive line separators.
const List<String> _pieces = <String>[
  'a',
  'Z',
  '0',
  ' ',
  '\u00e9',
  '\u00df',
  '\u65e5',
  '\u672c',
  '\u{1F47B}',
  '\uD800',
  '\uDC00',
  '"',
  '\\',
  '/',
  '\n',
  '\t',
  '\u0000',
  '\u001F',
  '\u007F',
  '\u2028',
];

/// Strings of up to 6 pieces, including the empty string.
Generator<String> get _string => any
    .listWithLengthInRange(0, 7, any.choose(_pieces))
    .map((parts) => parts.join());

/// Finite doubles in `[-1e9, 1e9]`, plus a few awkward ones: an integral
/// double (3.0), negative zero and a tiny fraction.
Generator<double> get _double => any.oneOf<double>(<Generator<double>>[
  any.doubleInRange(-1e9, 1e9),
  any.choose(<double>[3.0, -0.0, 1e-7, -1e9, 1e9]),
]);

/// Integers within +/-(2^53 - 1).
///
/// The big ones are built from three small pieces so no single draw needs a
/// range wider than 2^18 (kept web-safe); `a * 2^36 + b * 2^18 + c` stays
/// below 2^53.
Generator<int> get _int => any.oneOf<int>(<Generator<int>>[
  any.intInRange(-1000, 1000),
  any.choose(<int>[_maxSafeInt, -_maxSafeInt, _maxSafeInt - 1, 0]),
  any.combine4(
    any.intInRange(0, 1 << 17),
    any.intInRange(0, 1 << 18),
    any.intInRange(0, 1 << 18),
    any.bool,
    (a, b, c, negative) {
      final int magnitude = a * 68719476736 + b * 262144 + c;
      return negative ? -magnitude : magnitude;
    },
  ),
]);

Generator<Object?> get _scalar => any.oneOf<Object?>(<Generator<Object?>>[
  any.always<Object?>(null),
  any.bool.map<Object?>((b) => b),
  _double.map<Object?>((d) => d),
  _int.map<Object?>((i) => i),
  _string.map<Object?>((s) => s),
]);

/// A value with up to [levels] more nested containers below it.
Generator<Object?> _value(int levels) {
  if (levels == 0) return _scalar;
  return any.oneOf<Object?>(<Generator<Object?>>[
    _scalar,
    _scalar,
    any
        .listWithLengthInRange(0, 5, _value(levels - 1))
        .map<Object?>((items) => items),
    _map(levels).map<Object?>((m) => m),
  ]);
}

/// A map with 0..4 entries whose values nest at most [levels] - 1 deeper. With
/// `levels` 3 the deepest structure is map -> list or map -> map or list.
Generator<JsonMap> _map(int levels) => any
    .listWithLengthInRange(
      0,
      5,
      any.combine2(
        _string,
        _value(levels - 1),
        (String k, Object? v) => MapEntry<String, Object?>(k, v),
      ),
    )
    .map(
      (entries) => <String, Object?>{
        for (final MapEntry<String, Object?> e in entries) e.key: e.value,
      },
    );

/// Safe maps: depth at most 3, at most 4 entries per map or list.
Generator<JsonMap> get _anySafeMap => _map(3);

/// Any version in `0..maxVersion`, with the edges overrepresented.
Generator<int> get _anyVersion => any.oneOf<int>(<Generator<int>>[
  any.intInRange(0, EnvelopeCodec.maxVersion + 1),
  any.choose(<int>[0, 1, 2, EnvelopeCodec.maxVersion]),
]);

/// Deep equality that is correct on the VM and on the web.
///
/// Numbers are compared with `==`, not with `identical` or a type check. After
/// a JSON round trip the VM turns `3.0` into the text `3.0` and back into a
/// `double`, while an integral value written as an `int` stays an `int`; on the
/// web both are the same JavaScript number. `3.0 == 3` is true in Dart on both
/// platforms, and `-0.0 == 0.0` is true as well, so a plain `==` on numbers
/// accepts exactly the differences that JSON cannot and need not preserve (the
/// int/double label of an integral value) and rejects every real change of
/// value. Maps must have the same keys, lists the same length and order, and
/// strings, bools and nulls must be equal. No other type is accepted.
bool _deepEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEqual(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  if (a is String && b is String) return a == b;
  if (a is bool && b is bool) return a == b;
  return a == null && b == null;
}

void main() {
  group('EnvelopeCodec property: round trip', () {
    var executedRuns = 0;

    // Feature: crypt-storage, Property 2: envelope round trip
    // Validates: Requirements 6.3, 6.5, 12.2
    Glados2(_anySafeMap, _anyVersion, ExploreConfig(numRuns: _numRuns)).test(
      'parse(encode(v, m)) returns version v and a map equal to m',
      (map, version) {
        executedRuns++;

        final String text = EnvelopeCodec.encode(version, map);
        final Envelope parsed = EnvelopeCodec.parse(text);

        expect(parsed.version, version, reason: 'version=$version map=$map');
        expect(
          _deepEqual(parsed.data, map),
          isTrue,
          reason: 'version=$version map=$map text=$text parsed=${parsed.data}',
        );
      },
    );

    test('property body executed for every requested run', () {
      expect(executedRuns, _numRuns);
    });
  });
}
