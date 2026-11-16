import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:glados/glados.dart' hide expect, group, test;

// Pure support code: no dart:io, no hive_ce, no Flutter. It runs in Chrome.
//
// Only web-safe glados generators are used (`simple`, `combine4`). Strings
// come from the piece list below, never from a glados string generator.

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

/// The four fact keys the offline engine reads, written out here as text.
const List<String> knownFactKeys = <String>[
  'streakCount',
  'daysSinceLastCommit',
  'ghostName',
  'projectName',
];

/// The seeds at the edges of the range and of the 2^31 boundary.
const List<int> edgeSeeds = <int>[
  0,
  1,
  2147483647,
  2147483648,
  4294967294,
  4294967295,
];

/// The limits worth hitting often.
const List<int> edgeMaxLengths = <int>[16, 17, 80, 5000];

/// The marker that custom purpose ids may carry, so a test can recognise
/// that an id never reaches a reply.
const String purposeMarker = 'zzmark_';

// Pieces for strings: ASCII, spaces, accents, CJK, emoji, control characters,
// lone surrogates, banned words and a 40-unit text.
final List<String> _pieces = <String>[
  'a',
  'Z',
  '7',
  ' ',
  '  ',
  'é',
  'ß',
  '漢',
  '字',
  '\u{1F47B}',
  '\u{1F383}',
  '\n',
  '\t',
  '\u0000',
  '\u0001',
  '\u007F',
  '\u0085',
  '\u00A0',
  '\u3000',
  '\uD800',
  '\uDC00',
  'Blood',
  'KILL',
  'murder',
  '"',
  '\\',
  'W' * 40,
];

String _randomString(math.Random random) {
  final int length = random.nextInt(7);
  return <String>[
    for (int i = 0; i < length; i++) _pieces[random.nextInt(_pieces.length)],
  ].join();
}

const String _idFirst = 'abcdefghijklmnopqrstuvwxyz';
const String _idRest = 'abcdefghijklmnopqrstuvwxyz0123456789_';

String _randomIdentifier(math.Random random, {String prefix = ''}) {
  final int length = 1 + random.nextInt(64 - prefix.length);
  final StringBuffer buffer = StringBuffer(prefix);
  for (int i = 0; i < length; i++) {
    final String alphabet = (i == 0 && prefix.isEmpty) ? _idFirst : _idRest;
    buffer.write(alphabet[random.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}

/// Generates purposes: the known constants, custom valid identifiers,
/// identifiers that reuse a known id, and custom ids with the `zzmark_` marker.
///
/// Every value is a valid purpose. Shrinks towards `ghostMoodLine`.
Generator<AiPurpose> get anyAiPurpose => any.simple<AiPurpose>(
  generate: (math.Random random, int size) {
    switch (random.nextInt(5)) {
      case 0:
        return random.nextBool()
            ? AiPurpose.ghostMoodLine
            : AiPurpose.seanceVerdict;
      case 1:
        return AiPurpose(_randomIdentifier(random));
      case 2:
        return AiPurpose(
          random.nextBool() ? 'ghost_mood_line' : 'seance_verdict',
        );
      case 3:
        return AiPurpose(_randomIdentifier(random, prefix: purposeMarker));
      default:
        // The longest valid identifier.
        return AiPurpose('x' * AiPurpose.maxIdLength);
    }
  },
  shrink: (AiPurpose p) => p == AiPurpose.ghostMoodLine
      ? const <AiPurpose>[]
      : const <AiPurpose>[AiPurpose.ghostMoodLine],
);

// Never both 0.0 and -0.0: `any.choose` asserts distinct values, and the two
// are equal on web. This list is used with a plain index, but stays distinct.
const List<double> _specialDoubles = <double>[
  0.5,
  -2.5,
  5.0,
  1000000.0,
  double.nan,
  double.infinity,
  double.negativeInfinity,
  1e300,
];

const List<int> _specialInts = <int>[
  0,
  1,
  5,
  -1,
  -7,
  1000000,
  1000001,
  4294967295,
  9007199254740991, // 2^53 - 1
  -9007199254740991,
];

Object? _randomValue(math.Random random, int depth) {
  switch (random.nextInt(depth > 0 ? 10 : 8)) {
    case 0:
      return _specialInts[random.nextInt(_specialInts.length)];
    case 1:
      return random.nextInt(100);
    case 2:
      return _specialDoubles[random.nextInt(_specialDoubles.length)];
    case 3:
      return random.nextDouble() * 200 - 100;
    case 4:
    case 5:
      return _randomString(random);
    case 6:
      return random.nextBool();
    case 7:
      return null;
    case 8:
      return <Object?>[
        for (int i = random.nextInt(3); i > 0; i--)
          _randomValue(random, depth - 1),
      ];
    default:
      return <String, Object?>{
        for (int i = random.nextInt(3); i > 0; i--)
          _randomString(random): _randomValue(random, depth - 1),
      };
  }
}

/// Generates fact maps. About 80% of the entries use a known key. The rest
/// are extra keys, including the empty key. Values include `int`, whole and
/// fractional `double`, negatives, 2^53 - 1, `NaN`, infinity, lists, maps and
/// strings built from the piece list.
///
/// Shrinks by dropping one entry or all of them.
Generator<Map<String, Object?>> get anyFacts =>
    any.simple<Map<String, Object?>>(
      generate: (math.Random random, int size) {
        final int count = random.nextInt(6);
        final Map<String, Object?> facts = <String, Object?>{};
        for (int i = 0; i < count; i++) {
          final String key;
          if (random.nextInt(100) < 80) {
            key = knownFactKeys[random.nextInt(knownFactKeys.length)];
          } else if (random.nextInt(4) == 0) {
            key = '';
          } else {
            key = 'extra_${random.nextInt(5)}';
          }
          facts[key] = _randomValue(random, 1);
        }
        return facts;
      },
      shrink: (Map<String, Object?> facts) sync* {
        if (facts.isEmpty) return;
        yield <String, Object?>{};
        for (final String key in facts.keys) {
          yield <String, Object?>{...facts}..remove(key);
        }
      },
    );

/// Generates seeds from 0 to 4294967295. About 20% come from [edgeSeeds],
/// otherwise `anyIntBetween(0, 4294967296)`. Shrinks towards 0.
Generator<int> get anySeed {
  final Generator<int> wide = anyIntBetween(0, 4294967296);
  return any.simple<int>(
    generate: (math.Random random, int size) {
      if (random.nextInt(100) < 20) {
        return edgeSeeds[random.nextInt(edgeSeeds.length)];
      }
      return wide(random, size).value;
    },
    shrink: (int v) => v == 0 ? const <int>[] : <int>[v ~/ 2],
  );
}

/// Generates limits from 16 to 5000. About 25% come from [edgeMaxLengths],
/// otherwise 16 to 200. Shrinks towards 16.
Generator<int> get anyMaxLength {
  final Generator<int> narrow = anyIntBetween(16, 201);
  return any.simple<int>(
    generate: (math.Random random, int size) {
      if (random.nextInt(100) < 25) {
        return edgeMaxLengths[random.nextInt(edgeMaxLengths.length)];
      }
      return narrow(random, size).value;
    },
    shrink: (int v) => v <= 16 ? const <int>[] : <int>[16 + (v - 16) ~/ 2],
  );
}

/// Generates valid requests. Facts may be odd, so the constructor must accept
/// them all.
Generator<AiRequest> get anyAiRequest =>
    any.combine4<AiPurpose, Map<String, Object?>, int, int, AiRequest>(
      anyAiPurpose,
      anyFacts,
      anyMaxLength,
      anySeed,
      (
        AiPurpose purpose,
        Map<String, Object?> facts,
        int maxLength,
        int seed,
      ) => AiRequest(
        purpose: purpose,
        facts: facts,
        maxLength: maxLength,
        seed: seed,
      ),
    );

/// Escapes [text] as a quoted string with only printable ASCII.
String escapeForReport(String text) {
  final StringBuffer buffer = StringBuffer('"');
  for (final int u in text.codeUnits) {
    if (u == 0x22) {
      buffer.write(r'\"');
    } else if (u == 0x5C) {
      buffer.write(r'\\');
    } else if (u == 0x0A) {
      buffer.write(r'\n');
    } else if (u == 0x09) {
      buffer.write(r'\t');
    } else if (u >= 0x20 && u < 0x7F) {
      buffer.writeCharCode(u);
    } else {
      buffer.write('\\u${u.toRadixString(16).toUpperCase().padLeft(4, '0')}');
    }
  }
  return (buffer..write('"')).toString();
}

String _describeValue(Object? value) {
  if (value is String) return escapeForReport(value);
  if (value is List<Object?>) {
    return '[${value.map(_describeValue).join(', ')}]';
  }
  if (value is Map<Object?, Object?>) {
    return '{${value.entries.map((MapEntry<Object?, Object?> e) => '${_describeValue(e.key)}: ${_describeValue(e.value)}').join(', ')}}';
  }
  return '$value';
}

/// A readable description of [request] for a failure message: the purpose id,
/// every fact with escaping, the limit and the seed.
String describeRequest(AiRequest request) {
  final String facts = request.facts.entries
      .map(
        (MapEntry<String, Object?> e) =>
            '${escapeForReport(e.key)}: ${_describeValue(e.value)}',
      )
      .join(', ');
  return 'AiRequest(purpose: ${request.purpose.id}, facts: {$facts}, '
      'maxLength: ${request.maxLength}, seed: ${request.seed})';
}
