// Feature: hauntagotchi-core, Property 22: Corrupt records are rejected
// Validates: Requirements 8.5

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show expect, group, throwsFormatException;
import 'package:glados/glados.dart' hide expect, group;
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';

import '../domain/support/haunt_generators.dart';

const int _numRuns = 200;

final LocalDay _today = LocalDay(2026, 6, 15);

final RunCounter _habitRuns = RunCounter();
final RunCounter _ghostRuns = RunCounter();

/// A corrupted stored record: [label] names the corruption, [json] is the
/// record a codec must refuse.
final class _Corrupt {
  const _Corrupt(this.label, this.json);

  /// What was broken, shown when a run fails.
  final String label;

  /// The corrupted record.
  final Map<String, Object?> json;

  @override
  String toString() => '$label: $json';
}

const List<String> _badDays = <String>[
  '2026-02-30',
  '2025-02-29',
  '2026-13-01',
  '2026-00-10',
  '2026-04-31',
  '2026-1-1',
  '26-01-01',
  'not a day',
  '',
  '2026/01/01',
];

const List<Object?> _wrongTypes = <Object?>[5, true, null, <Object?>[]];

String _longName(math.Random random) => 'a' * (41 + random.nextInt(30));

String _blankName(math.Random random) =>
    <String>['', ' ', '   ', '\t', '\n ', '\u00A0'][random.nextInt(6)];

T _pick<T>(math.Random random, List<T> items) =>
    items[random.nextInt(items.length)];

/// Breaks a valid habit record in one of the ways Requirement 8.5 lists.
_Corrupt _corruptHabit(Habit habit, math.Random random) {
  const HabitCodec codec = HabitCodec();
  final Map<String, Object?> json = Map<String, Object?>.of(
    codec.encode(habit),
  );
  const List<String> keys = <String>[
    'id',
    'name',
    'created',
    'completed',
    'archived',
  ];
  final int kind = random.nextInt(9);
  switch (kind) {
    case 0:
      json['name'] = _blankName(random);
      return _Corrupt('blank name', json);
    case 1:
      json['name'] = _longName(random);
      return _Corrupt('name over 40', json);
    case 2:
      json['created'] = _pick(random, _badDays);
      return _Corrupt('malformed created day', json);
    case 3:
      json['completed'] = <Object?>[
        ...(json['completed']! as List<Object?>),
        _pick(random, _badDays),
      ];
      return _Corrupt('malformed completed day', json);
    case 4:
      json['archived'] = _pick(random, _badDays);
      return _Corrupt('malformed archived day', json);
    case 5:
      json.remove(_pick(random, keys));
      return _Corrupt('missing field', json);
    case 6:
      final String key = _pick(random, keys);
      // `archived` may legally be null and `completed` may be an empty list.
      final List<Object?> options = switch (key) {
        'archived' => <Object?>[5, true, <Object?>[]],
        'completed' => <Object?>[5, true, null, 'x'],
        _ => _wrongTypes,
      };
      json[key] = _pick(random, options);
      return _Corrupt('wrong type for $key', json);
    case 7:
      json['archived'] = habit.createdDay
          .addDays(-(1 + random.nextInt(400)))
          .toIso();
      return _Corrupt('archived before created', json);
    default:
      json['completed'] = <Object?>[
        ...(json['completed']! as List<Object?>),
        habit.createdDay.addDays(-(1 + random.nextInt(400))).toIso(),
      ];
      return _Corrupt('completed before created', json);
  }
}

/// Breaks a valid ghost record in one of the ways Requirement 8.5 lists.
_Corrupt _corruptGhost(Ghost ghost, math.Random random) {
  const GhostCodec codec = GhostCodec();
  final Map<String, Object?> json = Map<String, Object?>.of(
    codec.encode(ghost),
  );
  const List<String> keys = <String>[
    'name',
    'health',
    'lastSettled',
    'resurrections',
  ];
  switch (random.nextInt(8)) {
    case 0:
      json['name'] = _blankName(random);
      return _Corrupt('blank name', json);
    case 1:
      json['name'] = _longName(random);
      return _Corrupt('name over 40', json);
    case 2:
      json['health'] = -1 - random.nextInt(1000);
      return _Corrupt('health below 0', json);
    case 3:
      json['health'] = 101 + random.nextInt(1000);
      return _Corrupt('health above 100', json);
    case 4:
      json['lastSettled'] = _pick(random, _badDays);
      return _Corrupt('malformed lastSettled', json);
    case 5:
      json['resurrections'] = -1 - random.nextInt(1000);
      return _Corrupt('negative resurrections', json);
    case 6:
      json.remove(_pick(random, keys));
      return _Corrupt('missing field', json);
    default:
      final String key = _pick(random, keys);
      final bool numeric = key == 'health' || key == 'resurrections';
      json[key] = numeric
          ? _pick(random, <Object?>['5', true, null, <Object?>[]])
          : _pick(random, _wrongTypes);
      return _Corrupt('wrong type for $key', json);
  }
}

/// Generates a corrupted habit record built from a valid generated habit.
Generator<_Corrupt> get _anyCorruptHabit => any.simple<_Corrupt>(
  generate: (math.Random random, int size) =>
      _corruptHabit(anyHabit(_today)(random, size).value, random),
  shrink: (_Corrupt c) => const <_Corrupt>[],
);

/// Generates a corrupted ghost record built from a valid generated ghost.
Generator<_Corrupt> get _anyCorruptGhost => any.simple<_Corrupt>(
  generate: (math.Random random, int size) =>
      _corruptGhost(anyGhost(_today)(random, size).value, random),
  shrink: (_Corrupt c) => const <_Corrupt>[],
);

void main() {
  const HabitCodec habitCodec = HabitCodec();
  const GhostCodec ghostCodec = GhostCodec();

  group('Corrupt records are rejected (Property 22)', () {
    Glados(_anyCorruptHabit, ExploreConfig(numRuns: _numRuns)).test(
      'a corrupted habit record makes HabitCodec.decode throw FormatException',
      (_Corrupt c) {
        _habitRuns.increment();
        expect(() => habitCodec.decode(c.json), throwsFormatException);
      },
    );

    Glados(_anyCorruptGhost, ExploreConfig(numRuns: _numRuns)).test(
      'a corrupted ghost record makes GhostCodec.decode throw FormatException',
      (_Corrupt c) {
        _ghostRuns.increment();
        expect(() => ghostCodec.decode(c.json), throwsFormatException);
      },
    );

    test('every property body ran numRuns times', () {
      _habitRuns.expectRuns(_numRuns);
      _ghostRuns.expectRuns(_numRuns);
    });
  });
}
