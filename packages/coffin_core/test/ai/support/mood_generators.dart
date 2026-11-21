import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'ai_generators.dart';

// Pure support code: no dart:io, no hive_ce, no Flutter. It runs in Chrome.
//
// Only web-safe glados generators are used (`simple`, `combine5`). Strings
// come from a fixed alphabet, never from a glados string generator.

/// The five accepted mood fact values, written out as text.
const List<String> validMoodValues = <String>[
  'thriving',
  'content',
  'hungry',
  'fading',
  'dead',
];

/// The four accepted event fact values, written out as text.
const List<String> validEventValues = <String>[
  'appOpened',
  'checkedOff',
  'moodChanged',
  'resurrected',
];

/// Strings that look close to a valid value but are not exact matches.
const List<String> _invalidNames = <String>[
  '',
  ' ',
  'fed',
  'rising',
  'Thriving',
  'DEAD',
  'AppOpened',
  'checkedoff',
  ' dead',
  'dead ',
  'thriving\n',
  'unknown',
  'ghost_mood_line',
];

/// Values that are not strings at all.
final List<Object?> _nonStringValues = <Object?>[
  null,
  0,
  1,
  -1,
  2.5,
  true,
  false,
  <Object?>['dead'],
  <String, Object?>{'dead': 1},
];

Object? _nameValue(
  math.Random random,
  List<String> valid,
  List<String> extraInvalid,
) {
  final int roll = random.nextInt(100);
  if (roll < 50) return valid[random.nextInt(valid.length)];
  if (roll < 75) {
    final List<String> invalid = <String>[..._invalidNames, ...extraInvalid];
    return invalid[random.nextInt(invalid.length)];
  }
  return _nonStringValues[random.nextInt(_nonStringValues.length)];
}

Generator<Object?> _anyNameFact(List<String> valid, List<String> extra) =>
    any.simple<Object?>(
      generate: (math.Random random, int size) =>
          _nameValue(random, valid, extra),
      shrink: (Object? v) =>
          v == valid.first ? const <Object?>[] : <Object?>[valid.first],
    );

/// Generates mood fact values: about half are valid mood names, the rest are
/// near misses (wrong case, spaces, an event name, `fed`, `rising`) or values
/// that are not strings. Shrinks towards `thriving`.
Generator<Object?> get anyMoodValue =>
    _anyNameFact(validMoodValues, validEventValues);

/// Generates event fact values: about half are valid event names, the rest
/// are near misses or values that are not strings. Shrinks towards
/// `appOpened`.
Generator<Object?> get anyEventValue =>
    _anyNameFact(validEventValues, validMoodValues);

/// The most days a generated streak reaches.
const int maxStreak = 1000000;

/// The longest generated ghost name.
const int maxNameLength = 40;

/// The alphabet of generated ghost names: letters, a space and an apostrophe.
/// It holds no digit, so a digit run in a rendered line is a streak.
const String nameAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGH '";

/// Generates streaks: `null` (absent) about one time in four, otherwise 1 to
/// 1000000, with 1, 2 and 1000000 drawn often. Shrinks towards 1.
Generator<int?> get anyStreak {
  final Generator<int> wide = anyIntBetween(1, maxStreak + 1);
  return any.simple<int?>(
    generate: (math.Random random, int size) {
      final int roll = random.nextInt(100);
      if (roll < 25) return null;
      if (roll < 35) return 1;
      if (roll < 45) return 2;
      if (roll < 55) return maxStreak;
      return wide(random, size).value;
    },
    shrink: (int? v) => v == null || v == 1 ? const <int?>[] : <int?>[1],
  );
}

/// Generates ghost names: `null` (absent) about one time in four, otherwise 1
/// to 40 characters from [nameAlphabet], with the full 40 drawn often. Never
/// holds a digit. Shrinks towards `a`.
Generator<String?> get anyGhostName => any.simple<String?>(
  generate: (math.Random random, int size) {
    final int roll = random.nextInt(100);
    if (roll < 25) return null;
    final int length = roll < 40 ? maxNameLength : 1 + random.nextInt(40);
    return <String>[
      for (int i = 0; i < length; i++)
        nameAlphabet[random.nextInt(nameAlphabet.length)],
    ].join();
  },
  shrink: (String? v) =>
      v == null || v == 'a' ? const <String?>[] : <String?>['a'],
);

/// Generates mood requests: purpose `ghostMoodLine`, a mood and an event fact
/// (valid, invalid or not a string), an optional `streakCount` and an optional
/// `ghostName`, `maxLength` 16 to 200 and a seed from 0 to 4294967295.
///
/// Absent streaks and names are left out of the facts.
Generator<AiRequest> get anyMoodRequest =>
    any.combine6<Object?, Object?, int?, String?, int, int, AiRequest>(
      anyMoodValue,
      anyEventValue,
      anyStreak,
      anyGhostName,
      anyIntBetween(16, 201),
      anySeed,
      (
        Object? mood,
        Object? event,
        int? streak,
        String? name,
        int maxLength,
        int seed,
      ) => AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        facts: <String, Object?>{
          AiFactKeys.ghostMood: mood,
          AiFactKeys.ghostEvent: event,
          AiFactKeys.streakCount: ?streak,
          AiFactKeys.ghostName: ?name,
        },
        maxLength: maxLength,
        seed: seed,
      ),
    );
