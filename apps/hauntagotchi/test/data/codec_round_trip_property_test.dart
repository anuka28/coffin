// Feature: hauntagotchi-core, Property 20: Habit codec round trip
// Feature: hauntagotchi-core, Property 21: Ghost codec round trip
// Validates: Requirements 8.2, 8.3, 8.4

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isTrue;
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
final RunCounter _habitJsonRuns = RunCounter();
final RunCounter _ghostRuns = RunCounter();
final RunCounter _ghostJsonRuns = RunCounter();

/// Sends [encoded] through text JSON and back, like a real store would.
Map<String, Object?> _viaJson(Map<String, Object?> encoded) =>
    (jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>)
        .cast<String, Object?>();

void main() {
  const HabitCodec habitCodec = HabitCodec();
  const GhostCodec ghostCodec = GhostCodec();

  group('Habit codec round trip (Property 20)', () {
    Glados(anyHabit(_today), ExploreConfig(numRuns: _numRuns)).test(
      'decode(encode(habit)) equals the habit',
      (Habit h) {
        _habitRuns.increment();
        expect(habitCodec.decode(habitCodec.encode(h)), equals(h));
      },
    );

    Glados(anyHabit(_today), ExploreConfig(numRuns: _numRuns)).test(
      'decode(jsonDecode(jsonEncode(encode(habit)))) equals the habit',
      (Habit h) {
        _habitJsonRuns.increment();
        final Map<String, Object?> encoded = habitCodec.encode(h);
        final List<Object?> completed = encoded['completed']! as List<Object?>;
        final List<String> sorted = completed.cast<String>().toList()..sort();
        expect(completed, equals(sorted), reason: 'days must be sorted');
        expect(habitCodec.decode(_viaJson(encoded)), equals(h));
      },
    );

    test('every property body ran numRuns times', () {
      _habitRuns.expectRuns(_numRuns);
      _habitJsonRuns.expectRuns(_numRuns);
    });
  });

  group('Ghost codec round trip (Property 21)', () {
    Glados(anyGhost(_today), ExploreConfig(numRuns: _numRuns)).test(
      'decode(encode(ghost)) equals the ghost',
      (Ghost g) {
        _ghostRuns.increment();
        expect(ghostCodec.decode(ghostCodec.encode(g)), equals(g));
      },
    );

    Glados(anyGhost(_today), ExploreConfig(numRuns: _numRuns)).test(
      'decode(jsonDecode(jsonEncode(encode(ghost)))) equals the ghost',
      (Ghost g) {
        _ghostJsonRuns.increment();
        final Ghost back = ghostCodec.decode(_viaJson(ghostCodec.encode(g)));
        expect(back == g, isTrue);
        expect(back.health, equals(g.health));
        expect(back.resurrectionCount, equals(g.resurrectionCount));
      },
    );

    test('every property body ran numRuns times', () {
      _ghostRuns.expectRuns(_numRuns);
      _ghostJsonRuns.expectRuns(_numRuns);
    });
  });
}
