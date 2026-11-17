// Feature: hauntagotchi-core, Property 19: Add, rename and archive keep what they should
// Validates: Requirements 1.1, 1.4, 1.5, 1.6

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isA, isFalse, isNotEmpty, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_book.dart';
import 'package:hauntagotchi/src/domain/habit_result.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/domain/name_rules.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;

final RunCounter _runs = RunCounter();

HabitBook _changed(HabitResult result) {
  expect(result, isA<HabitChanged>());
  return (result as HabitChanged).book;
}

Habit _byId(HabitBook book, String id) =>
    book.all.singleWhere((Habit h) => h.id == id);

void main() {
  group('Property 19: add, rename and archive keep what they should', () {
    Glados3(
      anyLocalDay,
      anyIntBetween(0, 1 << 30),
      anyHabitName,
      ExploreConfig(numRuns: _numRuns),
    ).test('add, rename and archive keep what they should', (
      LocalDay today,
      int seed,
      String rawName,
    ) {
      _runs.increment();
      final math.Random random = math.Random(seed);
      final HabitBook book = anyBook(today)(random, 10).value;
      final bool validName = NameRules.violation(rawName) == null;

      // 1.1: add with a valid name.
      if (validName && book.canAdd) {
        final Set<String> oldIds = book.all.map((Habit h) => h.id).toSet();
        final HabitBook next = _changed(book.add(rawName, today: today));
        expect(next.all.length, equals(book.all.length + 1));
        expect(next.all.take(book.all.length).toList(), equals(book.all));
        final Habit added = next.all.last;
        expect(oldIds.contains(added.id), isFalse);
        expect(added.name, equals(rawName.trim()));
        expect(added.isActive, isTrue);
        expect(added.createdDay, equals(today));
        expect(added.completedDays, equals(<LocalDay>{}));
        expect(next.activeCount, equals(book.activeCount + 1));
      }

      final List<Habit> active = book.active;
      if (active.isEmpty) return;
      final Habit target = active[random.nextInt(active.length)];

      // 1.4: rename with a valid name.
      if (validName) {
        final HabitBook renamed = _changed(book.rename(target.id, rawName));
        final Habit after = _byId(renamed, target.id);
        expect(after.name, equals(rawName.trim()));
        expect(after.id, equals(target.id));
        expect(after.createdDay, equals(target.createdDay));
        expect(after.completedDays, equals(target.completedDays));
        expect(after.archivedDay, equals(target.archivedDay));
        expect(renamed.all.length, equals(book.all.length));
      }

      // 1.5 and 1.6: archive.
      final bool couldAdd = book.canAdd;
      final HabitBook archived = _changed(
        book.archive(target.id, today: today),
      );
      final Habit gone = _byId(archived, target.id);
      expect(gone.archivedDay, equals(today));
      expect(gone.isActive, isFalse);
      expect(gone.completedDays, equals(target.completedDays));
      expect(gone.name, equals(target.name));
      expect(gone.createdDay, equals(target.createdDay));
      expect(archived.all.length, equals(book.all.length));
      expect(archived.active.any((Habit h) => h.id == target.id), isFalse);
      expect(archived.activeCount, equals(book.activeCount - 1));
      expect(archived.canAdd, isTrue);
      if (!couldAdd) {
        expect(book.activeCount, equals(HabitBook.maxActive));
      }
    });

    test('a full book can add again after one archive', () {
      final LocalDay today = LocalDay(2026, 1, 1);
      final HabitBook full = HabitBook(<Habit>[
        for (int i = 1; i <= HabitBook.maxActive; i++)
          Habit(id: 'h$i', name: 'x', createdDay: today),
      ]);
      expect(full.canAdd, isFalse);
      final HabitBook freed = _changed(full.archive('h1', today: today));
      expect(freed.canAdd, isTrue);
      expect(freed.all, isNotEmpty);
    });

    test('every property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });
  });
}
