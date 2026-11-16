import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/offline_coffin_ai.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestFailure, expect, group, isTrue;
import 'package:glados/glados.dart' hide expect, group;

import 'support/ai_generators.dart';
import 'support/test_texts.dart';

/// Runs per property for Properties 1 to 9.
const int _numRuns = 500;

/// Asks a fresh [OfflineCoffinAI]. Each run owns its instance.
Future<AiReply> askOffline(AiRequest request) => OfflineCoffinAI().ask(request);

/// Fails with [request] and the escaped [reply] in the message.
Never failWith(AiRequest request, AiReply? reply, String what) {
  final String shown = reply == null
      ? '<none>'
      : '"${escapeForReport(reply.text)}" (length ${reply.text.length})';
  throw TestFailure('$what\n  ${describeRequest(request)}\n  reply: $shown');
}

/// Runs [check] on the reply for [request], wrapping any failure so the
/// message carries the request and the escaped reply.
Future<void> checkOffline(
  AiRequest request,
  void Function(AiReply reply) check,
) async {
  AiReply? reply;
  try {
    reply = await askOffline(request);
    check(reply);
  } on TestFailure catch (e) {
    failWith(request, reply, e.message ?? 'check failed');
  } on Object catch (e) {
    failWith(request, reply, 'unexpected error: $e');
  }
}

final RunCounter _property1Runs = RunCounter();
final RunCounter _property2Runs = RunCounter();
final RunCounter _property3Runs = RunCounter();
final RunCounter _property4Runs = RunCounter();
final RunCounter _property4HostileRuns = RunCounter();
final RunCounter _property5Runs = RunCounter();
final RunCounter _property5SurrogateRuns = RunCounter();
final RunCounter _property6Runs = RunCounter();
final RunCounter _property7Runs = RunCounter();
final RunCounter _property7ReplacedRuns = RunCounter();

// Hostile name pieces for Property 4. Only fragments that matter are kept.
//
// The shipped templates put a space around every name slot: the slot is
// followed by " drifts", " has", " is", " waits", " says" or " still" and is
// preceded by ". ", ", and " or the start of the line. A join is therefore
// only possible if the engine ever trims, collapses or drops that space, or if
// a name keeps a banned word hidden behind its own cleaning. So the list has:
// - banned words in mixed case (whole-word cleaning must be case-blind);
// - names that end in a banned prefix whose remainder is the start of a word
//   that follows a slot: "mur" + "der", "kil" + "l", "ma" + "im", "stabbe" +
//   "d", "gor" + "e", "severe" + "d";
// - names that start with such a remainder, so text before the slot (which
//   ends in a letter when a slot is mid-sentence) could join with them;
// - names ending in a fragment of the next word itself ("sti", "ha", "wai",
//   "sa", "dri"), so " still" or " has" cannot complete a banned word;
// - names such as `Murderous`, which hold a banned word as a prefix.
const List<String> _hostilePieces = <String>[
  'Blood',
  'KILL',
  'mUrDeR',
  'GORE',
  'Slaughter',
  'DISMEMBER',
  'mutilat',
  'Behead',
  'Murderous',
  'Killer',
  'Bloody',
  'Gory',
  'Massacre',
  'Torture',
  // Endings that miss a banned word by one fragment.
  'Mur',
  'der',
  'Ki',
  'kil',
  're',
  'od',
  'ill',
  'aim',
  'Ma',
  'blo',
  'bl',
  'Gor',
  'slaughte',
  'dismembe',
  'stabbe',
  'severe',
  'Strangl',
  'Torture',
  'tortu',
  // Fragments that match the real templates' word boundaries.
  'sti',
  'ha',
  'wai',
  'sa',
  'dri',
  'i',
  's',
  'd',
  'l',
  ' ',
  'é',
  '\u{1F47B}',
];

final Set<String> _hostileNames = <String>{};

String _hostileName(math.Random random) {
  final int count = 1 + random.nextInt(3);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i++) {
    if (i > 0 && random.nextInt(4) == 0) buffer.write(' ');
    buffer.write(_hostilePieces[random.nextInt(_hostilePieces.length)]);
  }
  final String name = buffer.toString();
  _hostileNames.add(name);
  return name;
}

/// Requests whose `ghostName` and `projectName` often come from the hostile
/// piece list. The rest of the request is `anyAiRequest` unchanged.
Generator<AiRequest> get _anyHostileRequest =>
    any.combine2<AiRequest, List<String?>, AiRequest>(
      anyAiRequest,
      any.simple<List<String?>>(
        generate: (math.Random random, int size) => <String?>[
          random.nextInt(100) < 70 ? _hostileName(random) : null,
          random.nextInt(100) < 70 ? _hostileName(random) : null,
        ],
        shrink: (List<String?> v) => const <List<String?>>[],
      ),
      (AiRequest base, List<String?> names) {
        final Map<String, Object?> facts = <String, Object?>{...base.facts};
        if (names[0] != null) facts[AiFactKeys.ghostName] = names[0];
        if (names[1] != null) facts[AiFactKeys.projectName] = names[1];
        return AiRequest(
          purpose: base.purpose,
          facts: facts,
          maxLength: base.maxLength,
          seed: base.seed,
        );
      },
    );

bool _hasHostileName(AiRequest request) {
  final Object? ghost = request.facts[AiFactKeys.ghostName];
  final Object? project = request.facts[AiFactKeys.projectName];
  return (ghost is String && _hostileNames.contains(ghost)) ||
      (project is String && _hostileNames.contains(project));
}

// Name pieces for Property 5: emoji, lone surrogates, control characters,
// whitespace at the edges and long text. Padding of 22 to 23 units followed by
// an emoji puts the 24-unit name cap in the middle of a surrogate pair.
final List<String> _surrogatePieces = <String>[
  '\u{1F47B}',
  '\u{1F480}',
  '\u{1F383}',
  '\u{1F47B}\u{1F480}\u{1F383}\u{1F47B}\u{1F480}\u{1F383}',
  '\u2620',
  '\u26B0',
  '\uD83D',
  '\uDC7B',
  '\uDBFF',
  '\uDC00',
  '\u0000',
  '\u0007',
  '\u001B',
  '\u007F',
  '\u009F',
  ' ',
  'Ab',
  'caspar',
  'a' * 22 + '\u{1F47B}',
  'b' * 23 + '\u{1F480}',
  'c' * 23 + '\uD83D',
  'd' * 40,
  'long name ' * 12,
  for (final int unit in testWhitespaceUnits) String.fromCharCode(unit),
];

String _surrogateName(math.Random random) {
  final int count = 1 + random.nextInt(4);
  final StringBuffer buffer = StringBuffer();
  if (random.nextInt(3) == 0) {
    buffer.writeCharCode(
      testWhitespaceUnits.elementAt(random.nextInt(testWhitespaceUnits.length)),
    );
  }
  for (int i = 0; i < count; i++) {
    buffer.write(_surrogatePieces[random.nextInt(_surrogatePieces.length)]);
  }
  if (random.nextInt(3) == 0) {
    buffer.writeCharCode(
      testWhitespaceUnits.elementAt(random.nextInt(testWhitespaceUnits.length)),
    );
  }
  return buffer.toString();
}

/// Requests whose names are built from [_surrogatePieces], often with a small
/// `maxLength` (16 to 30) so truncation happens.
Generator<AiRequest> get _anySurrogateRequest =>
    any.combine2<AiRequest, List<Object?>, AiRequest>(
      anyAiRequest,
      any.simple<List<Object?>>(
        generate: (math.Random random, int size) => <Object?>[
          random.nextInt(100) < 80 ? _surrogateName(random) : null,
          random.nextInt(100) < 80 ? _surrogateName(random) : null,
          random.nextInt(100) < 40 ? 16 + random.nextInt(15) : null,
        ],
        shrink: (List<Object?> v) => const <List<Object?>>[],
      ),
      (AiRequest base, List<Object?> overlay) {
        final Map<String, Object?> facts = <String, Object?>{...base.facts};
        if (overlay[0] != null) facts[AiFactKeys.ghostName] = overlay[0];
        if (overlay[1] != null) facts[AiFactKeys.projectName] = overlay[1];
        return AiRequest(
          purpose: base.purpose,
          facts: facts,
          maxLength: (overlay[2] as int?) ?? base.maxLength,
          seed: base.seed,
        );
      },
    );

bool _nameHasSurrogateOrEmoji(Object? name) =>
    name is String && (countEmoji(name) > 0 || hasLoneSurrogate(name));

bool _hasSurrogateName(AiRequest request) =>
    _nameHasSurrogateOrEmoji(request.facts[AiFactKeys.ghostName]) ||
    _nameHasSurrogateOrEmoji(request.facts[AiFactKeys.projectName]);

// Pieces for the custom purpose ids of Property 6. The marker comes first, so
// no id equals a known identifier. Pieces total at most 6 * 9 = 54 units, so
// an id is at most 7 + 54 + 2 = 63 units, under the limit of 64.
const List<String> _idPieces = <String>[
  'a',
  'b',
  'z',
  '0',
  '9',
  '_',
  '__',
  'ghost',
  'mood',
  'line',
  'seance',
  'verdict',
  'blood',
  'kill',
  'name',
  'xxxxxxxxx',
];

String _customId(math.Random random) {
  final int count = random.nextInt(7);
  final StringBuffer buffer = StringBuffer(purposeMarker);
  for (int i = 0; i < count; i++) {
    buffer.write(_idPieces[random.nextInt(_idPieces.length)]);
  }
  return buffer.toString();
}

/// A request and two distinct custom purposes that carry the marker.
final class _PurposeCase {
  const _PurposeCase(this.base, this.first, this.second);

  final AiRequest base;
  final AiPurpose first;
  final AiPurpose second;

  AiRequest withPurpose(AiPurpose purpose) => AiRequest(
    purpose: purpose,
    facts: base.facts,
    maxLength: base.maxLength,
    seed: base.seed,
  );
}

Generator<_PurposeCase> get _anyPurposeCase =>
    any.combine2<AiRequest, List<String>, _PurposeCase>(
      anyAiRequest,
      any.simple<List<String>>(
        generate: (math.Random random, int size) {
          final String a = _customId(random);
          String b = _customId(random);
          if (b == a) b = '${b}_2';
          return <String>[a, b];
        },
        shrink: (List<String> v) => const <List<String>>[],
      ),
      (AiRequest base, List<String> ids) =>
          _PurposeCase(base, AiPurpose(ids[0]), AiPurpose(ids[1])),
    );

// Property 7. Count facts are overlaid with ints from the edges 1, 2, 999999
// and 1000000, from `anyIntBetween(1, 1000001)`, and now and then with 0 or
// values outside 1 to 1000000, which the property must leave unchanged.
const List<int> _countEdges = <int>[1, 2, 999999, 1000000];
const List<int> _countOutside = <int>[
  0,
  -1,
  -1000000,
  1000001,
  2000000,
  4294967295,
];
const List<String> _countKeys = <String>[
  AiFactKeys.streakCount,
  AiFactKeys.daysSinceLastCommit,
];

bool _isReplaceableCount(Object? value) =>
    value is int && value >= 1 && value <= 1000000;

/// Requests whose count facts mostly hold an `int` from 1 to 1000000.
Generator<AiRequest> get _anyCountRequest =>
    any.combine4<AiRequest, int, int, List<int>, AiRequest>(
      anyAiRequest,
      anyIntBetween(1, 1000001),
      anyIntBetween(1, 1000001),
      any.simple<List<int>>(
        // Per key: a mode 0..9 and an index for the edge or outside lists.
        generate: (math.Random random, int size) => <int>[
          random.nextInt(10),
          random.nextInt(1000),
          random.nextInt(10),
          random.nextInt(1000),
        ],
        shrink: (List<int> v) => const <List<int>>[],
      ),
      (AiRequest base, int wide0, int wide1, List<int> picks) {
        final Map<String, Object?> facts = <String, Object?>{...base.facts};
        final List<int> wide = <int>[wide0, wide1];
        for (int i = 0; i < _countKeys.length; i++) {
          final int mode = picks[i * 2];
          final int index = picks[i * 2 + 1];
          if (mode < 3) {
            facts[_countKeys[i]] = _countEdges[index % _countEdges.length];
          } else if (mode < 7) {
            facts[_countKeys[i]] = wide[i];
          } else if (mode == 7) {
            facts[_countKeys[i]] = _countOutside[index % _countOutside.length];
          }
          // Modes 8 and 9 keep whatever the base request holds.
        }
        return AiRequest(
          purpose: base.purpose,
          facts: facts,
          maxLength: base.maxLength,
          seed: base.seed,
        );
      },
    );

// Property 8. The "usable" oracle is written here from the rule text. A count
// is an int or a whole finite double in 1..1000000. A name is usable when its
// cleaned form is not blank and has no word of the test-declared banned list.
// The test calls `TextRules.cleanName` only to get the cleaned name, because
// cleaning is checked on its own by Property 10. "Banned" is decided with
// `testBannedWords`, never with the library list.
final RunCounter _property8Runs = RunCounter();
final RunCounter _property8RemovedRuns = RunCounter();
final RunCounter _property8ZeroRuns = RunCounter();

bool _isUsableCount(Object? value) {
  if (value is! num || !value.isFinite) return false;
  if (value != value.truncateToDouble()) return false;
  return value >= 1 && value <= 1000000;
}

bool _isUsableName(Object? value) {
  if (value is! String) return false;
  final String cleaned = TextRules.cleanName(value);
  return !isTestBlank(cleaned) && !hasTestBannedWord(cleaned);
}

bool _isUsableFact(String key, Object? value) {
  if (_countKeys.contains(key)) return _isUsableCount(value);
  if (key == AiFactKeys.ghostName || key == AiFactKeys.projectName) {
    return _isUsableName(value);
  }
  return false;
}

final List<Object?> _unusableValues = <Object?>[
  0,
  0.0,
  -0.0,
  -1,
  0.5,
  double.nan,
  double.infinity,
  double.negativeInfinity,
  1000001,
  '5',
  true,
  null,
  <Object?>[1, 2],
  <String, Object?>{'a': 1},
  '',
  '   ',
  '\u0000\n',
  'Murderous',
  'Blood',
  'KILL bill',
];

const List<Object?> _usableValues = <Object?>[
  1,
  5,
  5.0,
  1000000,
  'Ada',
  'Moss',
];

/// Requests with unusable values on the known keys, plus unknown keys and the
/// empty key. A usable value is mixed in now and then, so some facts stay.
Generator<AiRequest> get _anyUnusableRequest =>
    any.combine2<AiRequest, Map<String, Object?>, AiRequest>(
      anyAiRequest,
      any.simple<Map<String, Object?>>(
        generate: (math.Random random, int size) {
          final Map<String, Object?> overlay = <String, Object?>{};
          for (final String key in knownFactKeys) {
            final int roll = random.nextInt(100);
            if (roll < 55) {
              overlay[key] =
                  _unusableValues[random.nextInt(_unusableValues.length)];
            } else if (roll < 70) {
              overlay[key] =
                  _usableValues[random.nextInt(_usableValues.length)];
            }
          }
          if (random.nextInt(100) < 50) {
            overlay[''] = _usableValues[random.nextInt(_usableValues.length)];
          }
          for (int i = random.nextInt(3); i > 0; i--) {
            overlay['unknown_${random.nextInt(4)}'] = random.nextBool()
                ? _usableValues[random.nextInt(_usableValues.length)]
                : _unusableValues[random.nextInt(_unusableValues.length)];
          }
          return overlay;
        },
        shrink: (Map<String, Object?> v) => const <Map<String, Object?>>[],
      ),
      (AiRequest base, Map<String, Object?> overlay) => AiRequest(
        purpose: base.purpose,
        facts: <String, Object?>{...base.facts, ...overlay},
        maxLength: base.maxLength,
        seed: base.seed,
      ),
    );

// Property 9. One request per run: a known purpose with its own count fact.
// The count comes from the edges 1, 2, 10, 999999 and 1000000 or from
// `anyIntBetween(1, 1000001)`, and is sometimes a whole double. Extra facts
// are the other count (valid or not), names (clean, banned, long, emoji) and
// an unknown key. The longest filled count template is 78 units, so every
// `maxLength >= 80` leaves room for any name (names are capped at 24 units).
final RunCounter _property9Runs = RunCounter();
final RunCounter _property9DoubleRuns = RunCounter();
final RunCounter _property9SingularRuns = RunCounter();

const List<int> _property9Edges = <int>[1, 2, 10, 999999, 1000000];
const List<int> _property9MaxEdges = <int>[80, 81, 100, 5000];
const List<int> _property9SeedEdges = <int>[0, 1, 2147483647, 4294967295];
final List<String> _property9Names = <String>[
  'Ada',
  'Moss',
  'Blood',
  'KILL bill',
  'Murderous',
  'Gory Gorey',
  '   ',
  '',
  'W' * 24,
  'W' * 40,
  '\u{1F47B}' * 12,
  '\u{1F47B}' * 14,
  'Zo\u00EB 1',
  '12',
  '\uD83D',
];
const List<Object?> _property9OtherCounts = <Object?>[
  1,
  5,
  11,
  1000000,
  0,
  -3,
  2.5,
  1000001,
  '7',
  null,
  true,
];

/// A generated Property 9 case.
final class _FactCase {
  const _FactCase(this.request, this.count, this.asDouble);

  final AiRequest request;
  final int count;
  final bool asDouble;
}

Generator<_FactCase> get _anyFactCase =>
    any.combine4<int, int, int, List<int>, _FactCase>(
      anyIntBetween(1, 1000001),
      anyIntBetween(80, 401),
      anyIntBetween(0, 4294967296),
      any.simple<List<int>>(
        generate: (math.Random random, int size) => <int>[
          random.nextInt(100), // count: edge when < 40
          random.nextInt(_property9Edges.length),
          random.nextInt(2), // purpose
          random.nextInt(100), // whole double when < 25
          random.nextInt(100), // maxLength edge when < 25
          random.nextInt(_property9MaxEdges.length),
          random.nextInt(100), // seed edge when < 20
          random.nextInt(_property9SeedEdges.length),
          random.nextInt(100), // ghostName present when < 60
          random.nextInt(_property9Names.length),
          random.nextInt(100), // projectName present when < 60
          random.nextInt(_property9Names.length),
          random.nextInt(100), // other count present when < 60
          random.nextInt(_property9OtherCounts.length),
          random.nextInt(100), // unknown key present when < 30
        ],
        shrink: (List<int> v) => const <List<int>>[],
      ),
      (int wideCount, int wideMax, int wideSeed, List<int> p) {
        final int count = p[0] < 40 ? _property9Edges[p[1]] : wideCount;
        final bool ghost = p[2] == 0;
        final bool asDouble = p[3] < 25;
        final int maxLength = p[4] < 25 ? _property9MaxEdges[p[5]] : wideMax;
        final int seed = p[6] < 20 ? _property9SeedEdges[p[7]] : wideSeed;
        final String ownKey = ghost
            ? AiFactKeys.streakCount
            : AiFactKeys.daysSinceLastCommit;
        final String otherKey = ghost
            ? AiFactKeys.daysSinceLastCommit
            : AiFactKeys.streakCount;
        final Map<String, Object?> facts = <String, Object?>{
          if (p[8] < 60) AiFactKeys.ghostName: _property9Names[p[9]],
          if (p[10] < 60) AiFactKeys.projectName: _property9Names[p[11]],
          if (p[12] < 60) otherKey: _property9OtherCounts[p[13]],
          if (p[14] < 30) 'unknown_key': 7,
          ownKey: asDouble ? count.toDouble() : count,
        };
        return _FactCase(
          AiRequest(
            purpose: ghost ? AiPurpose.ghostMoodLine : AiPurpose.seanceVerdict,
            facts: facts,
            maxLength: maxLength,
            seed: seed,
          ),
          count,
          asDouble,
        );
      },
    );

/// True when [text] holds [needle] at an index whose previous unit is not an
/// ASCII digit, so "11 days" does not count as "1 day".
bool _containsAtBoundary(String text, String needle) {
  int from = 0;
  while (true) {
    final int index = text.indexOf(needle, from);
    if (index < 0) return false;
    final bool digitBefore =
        index > 0 &&
        text.codeUnitAt(index - 1) >= 0x30 &&
        text.codeUnitAt(index - 1) <= 0x39;
    if (!digitBefore) return true;
    from = index + 1;
  }
}

void main() {
  group('Property 1: Offline reply is non-empty and fits the limit', () {
    // Feature: coffin-ai, Property 1: Offline reply is non-empty and fits the limit
    // Validates: Requirements 2.4, 7.1, 7.2, 7.7, 13.2
    Glados(anyAiRequest, ExploreConfig(numRuns: _numRuns)).test(
      'reply has a visible character and length <= maxLength',
      (AiRequest request) async {
        _property1Runs.increment();
        await checkOffline(request, (AiReply reply) {
          if (isTestBlank(reply.text)) {
            throw TestFailure('reply is empty or whitespace only');
          }
          if (reply.text.length > request.maxLength) {
            throw TestFailure(
              'reply length ${reply.text.length} exceeds '
              'maxLength ${request.maxLength}',
            );
          }
        });
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property1Runs.runs > 0, isTrue);
      expect(_property1Runs.runs, _numRuns);
    });
  });

  group('Property 2: Offline replies are deterministic and stateless', () {
    // Feature: coffin-ai, Property 2: Offline replies are deterministic and stateless
    // Validates: Requirements 4.6, 5.1, 5.2, 13.3
    Glados2(anyAiRequest, anyAiRequest, ExploreConfig(numRuns: _numRuns)).test(
      'same request gives equal replies on any instance and history',
      (AiRequest r, AiRequest q) async {
        _property2Runs.increment();
        String where(String what) =>
            '$what\n  r: ${describeRequest(r)}\n  q: ${describeRequest(q)}';
        try {
          final OfflineCoffinAI used = OfflineCoffinAI();
          final AiReply first = await used.ask(r);
          final AiReply second = await used.ask(r);
          final AiReply fresh = await OfflineCoffinAI().ask(r);
          final OfflineCoffinAI busy = OfflineCoffinAI();
          await busy.ask(q);
          final AiReply afterOther = await busy.ask(r);

          if (first != second) {
            throw TestFailure(where('second ask on one instance differs'));
          }
          if (first != fresh) {
            throw TestFailure(where('fresh instance differs'));
          }
          if (first != afterOther) {
            throw TestFailure(where('ask after another request differs'));
          }
        } on TestFailure {
          rethrow;
        } on Object catch (e) {
          throw TestFailure(where('unexpected error: $e'));
        }
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property2Runs.runs > 0, isTrue);
      expect(_property2Runs.runs, _numRuns);
    });
  });

  group('Property 3: Offline always answers, with the offline source', () {
    // Feature: coffin-ai, Property 3: Offline always answers, with the offline source
    // Validates: Requirements 1.4, 4.3, 4.8, 13.6
    Glados(anyAiRequest, ExploreConfig(numRuns: _numRuns)).test(
      'ask does not throw synchronously and completes with an offline reply',
      (AiRequest request) async {
        _property3Runs.increment();
        String where(String what) => '$what\n  ${describeRequest(request)}';

        final OfflineCoffinAI ai = OfflineCoffinAI();
        Future<AiReply> future;
        try {
          future = ai.ask(request);
        } on Object catch (e) {
          throw TestFailure(where('ask threw synchronously: $e'));
        }

        AiReply reply;
        try {
          reply = await future;
        } on Object catch (e) {
          throw TestFailure(where('future completed with an error: $e'));
        }

        if (reply.source != ReplySource.offline) {
          throw TestFailure(
            where('source is ${reply.source}, expected ReplySource.offline'),
          );
        }
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property3Runs.runs > 0, isTrue);
      expect(_property3Runs.runs, _numRuns);
    });
  });

  group('Property 4: No banned word in the reply', () {
    // Feature: coffin-ai, Property 4: No banned word in the reply
    // Validates: Requirements 8.3, 8.4, 8.10, 8.13, 13.4
    Glados(_anyHostileRequest, ExploreConfig(numRuns: _numRuns)).test(
      'folded reply contains no word of the test banned list',
      (AiRequest request) async {
        _property4Runs.increment();
        if (_hasHostileName(request)) _property4HostileRuns.increment();
        await checkOffline(request, (AiReply reply) {
          final String folded = asciiFold(reply.text);
          for (final String word in testBannedWords) {
            if (folded.contains(word)) {
              throw TestFailure('reply contains banned word "$word"');
            }
          }
          if (hasTestBannedWord(reply.text)) {
            throw TestFailure('reply contains a banned word');
          }
        });
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property4Runs.runs > 0, isTrue);
      expect(_property4Runs.runs, _numRuns);
    });

    test('some runs carried a hostile name', () {
      // ignore: avoid_print
      print('Property 4 hostile-name runs: ${_property4HostileRuns.runs}');
      expect(_property4HostileRuns.runs > 0, isTrue);
    });
  });

  group('Property 5: No lone surrogate and no edge whitespace', () {
    // Feature: coffin-ai, Property 5: No lone surrogate and no edge whitespace
    // Validates: Requirements 6.10, 7.3, 7.5, 13.5
    Glados(_anySurrogateRequest, ExploreConfig(numRuns: _numRuns)).test(
      'reply has no unpaired surrogate and no edge whitespace',
      (AiRequest request) async {
        _property5Runs.increment();
        if (_hasSurrogateName(request)) _property5SurrogateRuns.increment();
        await checkOffline(request, (AiReply reply) {
          if (hasLoneSurrogate(reply.text)) {
            throw TestFailure('reply has an unpaired surrogate');
          }
          if (hasEdgeWhitespace(reply.text)) {
            throw TestFailure('reply starts or ends with whitespace');
          }
        });
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property5Runs.runs > 0, isTrue);
      expect(_property5Runs.runs, _numRuns);
    });

    test('some runs carried an emoji or a lone surrogate in a name', () {
      // ignore: avoid_print
      print('Property 5 surrogate-name runs: ${_property5SurrogateRuns.runs}');
      expect(_property5SurrogateRuns.runs > 0, isTrue);
    });
  });

  group('Property 6: The purpose identifier never changes or appears in the '
      'reply', () {
    // Feature: coffin-ai, Property 6: The purpose identifier never changes or appears in the reply
    // Validates: Requirements 2.16, 2.17, 2.18, 13.13, 13.14
    Glados(_anyPurposeCase, ExploreConfig(numRuns: _numRuns)).test(
      'custom ids stay out of the reply and do not change it',
      (_PurposeCase c) async {
        _property6Runs.increment();
        final AiRequest r1 = c.withPurpose(c.first);
        final AiRequest r2 = c.withPurpose(c.second);
        String where(String what, [AiReply? a, AiReply? b]) =>
            '$what\n  request 1: ${describeRequest(r1)}'
            '\n  request 2: ${describeRequest(r2)}'
            '${a == null ? '' : '\n  reply 1: ${escapeForReport(a.text)}'}'
            '${b == null ? '' : '\n  reply 2: ${escapeForReport(b.text)}'}';
        try {
          final AiReply a = await askOffline(r1);
          final AiReply b = await askOffline(r2);
          for (final (AiPurpose p, AiReply reply) in <(AiPurpose, AiReply)>[
            (c.first, a),
            (c.second, b),
          ]) {
            if (reply.text.contains(p.id)) {
              throw TestFailure(where('reply contains the id ${p.id}', a, b));
            }
            if (reply.text.contains('zzmark')) {
              throw TestFailure(where('reply contains the marker', a, b));
            }
          }
          if (a != b) {
            throw TestFailure(where('replies differ for two custom ids', a, b));
          }

          // Known identifiers given as new objects match the constants.
          final Map<AiPurpose, AiPurpose> known = <AiPurpose, AiPurpose>{
            AiPurpose('ghost_mood_line'): AiPurpose.ghostMoodLine,
            AiPurpose('seance_verdict'): AiPurpose.seanceVerdict,
          };
          for (final MapEntry<AiPurpose, AiPurpose> e in known.entries) {
            final AiRequest viaText = c.withPurpose(e.key);
            final AiRequest viaConst = c.withPurpose(e.value);
            final AiReply x = await askOffline(viaText);
            final AiReply y = await askOffline(viaConst);
            if (x != y) {
              throw TestFailure(
                'reply for AiPurpose(${e.key.id}) differs from the constant'
                '\n  text: ${describeRequest(viaText)}'
                '\n  const: ${describeRequest(viaConst)}'
                '\n  reply text: ${escapeForReport(x.text)}'
                '\n  reply const: ${escapeForReport(y.text)}',
              );
            }
          }
        } on TestFailure {
          rethrow;
        } on Object catch (e) {
          throw TestFailure(where('unexpected error: $e'));
        }
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property6Runs.runs > 0, isTrue);
      expect(_property6Runs.runs, _numRuns);
    });
  });

  group('Property 8: Unusable and extra facts behave like absent facts', () {
    // Feature: coffin-ai, Property 8: Unusable and extra facts behave like absent facts
    // Validates: Requirements 2.7, 5.6, 6.4, 6.6, 6.7
    Glados(_anyUnusableRequest, ExploreConfig(numRuns: _numRuns)).test('removing unusable and extra facts keeps the reply, and a zero count '
        'never prints "0 day"', (AiRequest request) async {
      _property8Runs.increment();
      final Map<String, Object?> kept = <String, Object?>{};
      for (final MapEntry<String, Object?> e in request.facts.entries) {
        if (_isUsableFact(e.key, e.value)) kept[e.key] = e.value;
      }
      if (kept.length != request.facts.length) {
        _property8RemovedRuns.increment();
      }
      if (request.facts.values.any((Object? v) => v is num && v == 0)) {
        _property8ZeroRuns.increment();
      }
      final AiRequest stripped = AiRequest(
        purpose: request.purpose,
        facts: kept,
        maxLength: request.maxLength,
        seed: request.seed,
      );

      // The zero request: both counts removed, then one or both set to a
      // zero of type int, 0.0 or -0.0. No other count can end in a zero.
      final Map<String, Object?> zeroFacts = <String, Object?>{...request.facts}
        ..removeWhere((String k, Object? v) => _countKeys.contains(k));
      final List<Object> zeros = <Object>[0, 0.0, -0.0];
      final int mode = request.seed % 3;
      if (mode != 1) {
        zeroFacts[AiFactKeys.streakCount] = zeros[(request.seed ~/ 3) % 3];
      }
      if (mode != 0) {
        zeroFacts[AiFactKeys.daysSinceLastCommit] =
            zeros[(request.seed ~/ 9) % 3];
      }
      final AiRequest zeroRequest = AiRequest(
        purpose: request.purpose,
        facts: zeroFacts,
        maxLength: request.maxLength,
        seed: request.seed,
      );

      AiReply? original;
      AiReply? cleaned;
      AiReply? zeroReply;
      String where(String what) =>
          '$what\n  original: ${describeRequest(request)}'
          '\n  stripped: ${describeRequest(stripped)}'
          '\n  zero request: ${describeRequest(zeroRequest)}'
          '\n  original reply: ${original == null ? '<none>' : escapeForReport(original.text)}'
          '\n  stripped reply: ${cleaned == null ? '<none>' : escapeForReport(cleaned.text)}'
          '\n  zero reply: ${zeroReply == null ? '<none>' : escapeForReport(zeroReply.text)}';
      try {
        original = await askOffline(request);
        cleaned = await askOffline(stripped);
        zeroReply = await askOffline(zeroRequest);
      } on Object catch (e) {
        throw TestFailure(where('unexpected error: $e'));
      }
      if (original != cleaned) {
        throw TestFailure(where('replies differ after removing facts'));
      }
      if (zeroReply.text.contains('0 day')) {
        throw TestFailure(where('zero count printed "0 day"'));
      }
    });

    test('ran exactly $_numRuns times', () {
      expect(_property8Runs.runs > 0, isTrue);
      expect(_property8Runs.runs, _numRuns);
    });

    test('some runs removed a fact and some had a zero count', () {
      // ignore: avoid_print
      print(
        'Property 8 removed runs: ${_property8RemovedRuns.runs}, '
        'zero-count runs: ${_property8ZeroRuns.runs}',
      );
      expect(_property8RemovedRuns.runs > 0, isTrue);
      expect(_property8ZeroRuns.runs > 0, isTrue);
    });
  });

  group('Property 7: A whole double is the same fact as the int', () {
    // Feature: coffin-ai, Property 7: A whole double is the same fact as the int
    // Validates: Requirements 5.5
    Glados(_anyCountRequest, ExploreConfig(numRuns: _numRuns)).test(
      'int counts in 1 to 1000000 and the same doubles give equal replies',
      (AiRequest request) async {
        _property7Runs.increment();
        final Map<String, Object?> facts = <String, Object?>{...request.facts};
        bool replaced = false;
        for (final MapEntry<String, Object?> e in request.facts.entries) {
          final Object? value = e.value;
          if (_countKeys.contains(e.key) && _isReplaceableCount(value)) {
            facts[e.key] = (value! as int).toDouble();
            replaced = true;
          }
        }
        if (replaced) _property7ReplacedRuns.increment();
        final AiRequest twin = AiRequest(
          purpose: request.purpose,
          facts: facts,
          maxLength: request.maxLength,
          seed: request.seed,
        );
        String where(String what, AiReply? a, AiReply? b) =>
            '$what\n  int request: ${describeRequest(request)}'
            '\n  double request: ${describeRequest(twin)}'
            '\n  int reply: ${a == null ? '<none>' : escapeForReport(a.text)}'
            '\n  double reply: ${b == null ? '<none>' : escapeForReport(b.text)}';
        AiReply? a;
        AiReply? b;
        try {
          a = await askOffline(request);
          b = await askOffline(twin);
        } on Object catch (e) {
          throw TestFailure(where('unexpected error: $e', a, b));
        }
        if (a != b) {
          throw TestFailure(where('replies differ', a, b));
        }
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property7Runs.runs > 0, isTrue);
      expect(_property7Runs.runs, _numRuns);
    });

    test('some runs replaced an int count with a double', () {
      // ignore: avoid_print
      print('Property 7 replaced runs: ${_property7ReplacedRuns.runs}');
      expect(_property7ReplacedRuns.runs > 0, isTrue);
    });
  });

  group('Property 9: Available facts are used when they fit', () {
    // Feature: coffin-ai, Property 9: Available facts are used when they fit
    // Validates: Requirements 6.3, 6.8, 6.9
    Glados(_anyFactCase, ExploreConfig(numRuns: _numRuns)).test(
      'reply holds the count followed by "day" for 1 and "days" otherwise',
      (_FactCase c) async {
        _property9Runs.increment();
        if (c.asDouble) _property9DoubleRuns.increment();
        if (c.count == 1) _property9SingularRuns.increment();
        final String expected = c.count == 1
            ? '${c.count} day'
            : '${c.count} days';
        await checkOffline(c.request, (AiReply reply) {
          if (!_containsAtBoundary(reply.text, expected)) {
            throw TestFailure(
              'reply does not contain "$expected" after a non-digit '
              '(count ${c.count}${c.asDouble ? ', given as a double' : ''})',
            );
          }
          if (c.count == 1 && _containsAtBoundary(reply.text, '1 days')) {
            throw TestFailure('reply says "1 days"');
          }
        });
      },
    );

    test('ran exactly $_numRuns times', () {
      expect(_property9Runs.runs > 0, isTrue);
      expect(_property9Runs.runs, _numRuns);
    });

    test('some runs used a double count and some used the count 1', () {
      // ignore: avoid_print
      print(
        'Property 9 double runs: ${_property9DoubleRuns.runs}, '
        'singular runs: ${_property9SingularRuns.runs}',
      );
      expect(_property9DoubleRuns.runs > 0, isTrue);
      expect(_property9SingularRuns.runs > 0, isTrue);
    });
  });
}
