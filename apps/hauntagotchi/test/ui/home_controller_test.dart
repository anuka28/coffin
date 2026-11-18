import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';
import 'package:hauntagotchi/src/ui/home_status.dart';
import 'package:hauntagotchi/src/ui/save_status.dart';

import '../support/fake_clock.dart';
import '../support/throwing_record_repository.dart';

/// Wraps a repository to log the order of writes and optionally hold them.
final class _LoggingRepository<T> implements RecordRepository<T> {
  _LoggingRepository(this.inner, this.label, this.log);

  final ThrowingRecordRepository<T> inner;
  final String label;
  final List<String> log;

  /// When set, [put] waits for it before writing.
  Completer<void>? gate;

  @override
  Future<void> put(String key, T record) async {
    final Completer<void>? held = gate;
    if (held != null) {
      await held.future;
    }
    await inner.put(key, record);
    log.add('$label:$key');
  }

  @override
  Future<T?> get(String key) => inner.get(key);

  @override
  Future<List<T>> getAll() => inner.getAll();

  @override
  Future<void> delete(String key) => inner.delete(key);

  @override
  Future<void> clear() => inner.clear();

  @override
  Stream<StorageEvent> watch() => inner.watch();

  @override
  Future<void> close() => inner.close();
}

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

Habit _habit(String id, {LocalDay? created}) =>
    Habit(id: id, name: 'Habit $id', createdDay: created ?? _today);

class _Rig {
  _Rig({bool isPersistent = true}) : clock = FakeClock(_morning) {
    habits = ThrowingRecordRepository<Habit>(
      MemoryRecordRepository<Habit>(
        codec: const HabitCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
    );
    ghost = ThrowingRecordRepository<Ghost>(
      MemoryRecordRepository<Ghost>(
        codec: const GhostCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
    );
    loggedHabits = _LoggingRepository<Habit>(habits, 'habit', log);
    loggedGhost = _LoggingRepository<Ghost>(ghost, 'ghost', log);
    controller = HomeController(
      clock: clock,
      openStorage: () async => HauntStorage(
        habits: loggedHabits,
        ghost: loggedGhost,
        isPersistent: isPersistent,
      ),
    );
  }

  final FakeClock clock;
  final List<String> log = <String>[];
  late final ThrowingRecordRepository<Habit> habits;
  late final ThrowingRecordRepository<Ghost> ghost;
  late final _LoggingRepository<Habit> loggedHabits;
  late final _LoggingRepository<Ghost> loggedGhost;
  late final HomeController controller;

  Future<void> seedHabit(Habit h) => habits.inner.put(h.id, h);
  Future<void> seedGhost(Ghost g) => ghost.inner.put(HauntStorage.ghostKey, g);

  bool doneToday(String id) => controller.haunting!.book.all
      .firstWhere((Habit h) => h.id == id)
      .isCompletedOn(controller.haunting!.today);
}

void main() {
  group('load', () {
    test('with no data creates a fresh ghost and saves it', () async {
      final _Rig rig = _Rig();
      expect(rig.controller.status, HomeStatus.loading);
      expect(rig.controller.haunting, isNull);

      await rig.controller.load();

      expect(rig.controller.status, HomeStatus.ready);
      expect(rig.controller.haunting!.book.all, isEmpty);
      expect(rig.controller.haunting!.ghost.health, Balance.maxHealth);
      expect(rig.controller.haunting!.today, _today);
      expect(rig.controller.saveStatus, SaveStatus.saved);
      expect(rig.controller.welcomeBack, isNull);
      expect(await rig.ghost.inner.get(HauntStorage.ghostKey), isNotNull);
    });

    test('with habits only builds a ghost and keeps the habits', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.seedHabit(_habit('h2'));

      await rig.controller.load();

      expect(rig.controller.status, HomeStatus.ready);
      expect(rig.controller.haunting!.book.all.map((Habit h) => h.id), <String>[
        'h1',
        'h2',
      ]);
      expect(rig.controller.haunting!.ghost.name, Balance.defaultGhostName);
      // Unchanged habits are not rewritten, only the ghost is saved.
      expect(rig.log, <String>['ghost:ghost']);
    });

    test('reports memory fallback when storage is not persistent', () async {
      final _Rig rig = _Rig(isPersistent: false);
      await rig.controller.load();
      expect(rig.controller.status, HomeStatus.ready);
      expect(rig.controller.isPersistent, isFalse);
    });

    test('is persistent when storage is persistent', () async {
      final _Rig rig = _Rig();
      await rig.controller.load();
      expect(rig.controller.isPersistent, isTrue);
    });

    test('shows loadError when a read fails, and load retries', () async {
      final _Rig rig = _Rig();
      rig.habits.failReads = true;

      await rig.controller.load();
      expect(rig.controller.status, HomeStatus.loadError);
      expect(rig.controller.haunting, isNull);

      rig.habits.failReads = false;
      await rig.controller.load();
      expect(rig.controller.status, HomeStatus.ready);
      expect(rig.controller.haunting, isNotNull);
    });

    test(
      'shows loadError when storage cannot be opened, then retries',
      () async {
        final _Rig rig = _Rig();
        int calls = 0;
        final HomeController controller = HomeController(
          clock: rig.clock,
          openStorage: () async {
            calls++;
            if (calls == 1) {
              throw StateError('cannot open');
            }
            return HauntStorage(
              habits: rig.loggedHabits,
              ghost: rig.loggedGhost,
              isPersistent: true,
            );
          },
        );
        addTearDown(controller.dispose);

        await controller.load();
        expect(controller.status, HomeStatus.loadError);

        await controller.load();
        expect(controller.status, HomeStatus.ready);
      },
    );
  });

  group('actions', () {
    test('addHabit saves the new habit then the ghost', () async {
      final _Rig rig = _Rig();
      await rig.controller.load();
      rig.log.clear();

      final HabitRejection? rejection = await rig.controller.addHabit('Walk');

      expect(rejection, isNull);
      expect(rig.controller.haunting!.book.all, hasLength(1));
      expect(rig.log, <String>['habit:h1', 'ghost:ghost']);
      expect(rig.controller.saveStatus, SaveStatus.saved);
    });

    test('addHabit returns the rejection reason for a bad name', () async {
      final _Rig rig = _Rig();
      await rig.controller.load();
      final HabitRejection? rejection = await rig.controller.addHabit('   ');
      expect(rejection, isNotNull);
      expect(rig.controller.haunting!.book.all, isEmpty);
    });

    test('toggle completes then undoes, writing habit before ghost', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      rig.log.clear();

      await rig.controller.toggle('h1');
      expect(rig.doneToday('h1'), isTrue);
      expect(rig.log, <String>['habit:h1', 'ghost:ghost']);

      await rig.controller.toggle('h1');
      expect(rig.doneToday('h1'), isFalse);
    });

    test('saveStatus stays saving until every write has finished', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      final Completer<void> gate = Completer<void>();
      rig.loggedGhost.gate = gate;
      rig.log.clear();

      final Future<void> pending = rig.controller.toggle('h1');
      await Future<void>.delayed(Duration.zero);

      // Shown at once in memory, habit written, ghost write still held.
      expect(rig.doneToday('h1'), isTrue);
      expect(rig.controller.saveStatus, SaveStatus.saving);
      expect(rig.log, <String>['habit:h1']);

      gate.complete();
      await pending;

      expect(rig.log, <String>['habit:h1', 'ghost:ghost']);
      expect(rig.controller.saveStatus, SaveStatus.saved);
    });
  });

  group('day change', () {
    test('refresh after a day change shows the new day and saves', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      rig.log.clear();

      rig.clock.advance(const Duration(days: 1));
      await rig.controller.refresh();

      expect(rig.controller.haunting!.today, _today.next);
      // The idle day was settled and written.
      expect(
        rig.controller.haunting!.ghost.health,
        Balance.maxHealth - Balance.neglectLoss,
      );
      expect(rig.log, contains('ghost:ghost'));
      final Ghost? stored = await rig.ghost.inner.get(HauntStorage.ghostKey);
      expect(stored, rig.controller.haunting!.ghost);
      expect(rig.controller.saveStatus, SaveStatus.saved);
    });

    test('refresh on the same day changes and writes nothing', () async {
      final _Rig rig = _Rig();
      await rig.controller.load();
      rig.log.clear();
      await rig.controller.refresh();
      expect(rig.log, isEmpty);
    });

    test('refresh before load does nothing', () async {
      final _Rig rig = _Rig();
      await rig.controller.refresh();
      expect(rig.controller.status, HomeStatus.loading);
      expect(rig.log, isEmpty);
    });

    test('a tap after a day change is ignored but shows the new day', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();

      rig.clock.advance(const Duration(days: 1));
      await rig.controller.toggle('h1');

      expect(rig.controller.haunting!.today, _today.next);
      expect(rig.doneToday('h1'), isFalse);

      // The next tap works on the new day.
      await rig.controller.toggle('h1');
      expect(rig.doneToday('h1'), isTrue);
    });

    test('an addHabit tap after a day change is ignored', () async {
      final _Rig rig = _Rig();
      await rig.controller.load();

      rig.clock.advance(const Duration(days: 1));
      final HabitRejection? rejection = await rig.controller.addHabit('Walk');

      expect(rejection, isNull);
      expect(rig.controller.haunting!.book.all, isEmpty);
      expect(rig.controller.haunting!.today, _today.next);
    });
  });

  group('failed writes', () {
    test('keep the state and show saveError', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      rig.habits.failPut = true;

      await rig.controller.toggle('h1');

      expect(rig.doneToday('h1'), isTrue);
      expect(rig.controller.saveStatus, SaveStatus.saveError);
      final Habit? stored = await rig.habits.inner.get('h1');
      expect(stored!.completedDays, isEmpty);
    });

    test('retrySave rewrites everything and returns to saved', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      rig.habits.failPut = true;
      await rig.controller.toggle('h1');
      expect(rig.controller.saveStatus, SaveStatus.saveError);

      rig.habits.failPut = false;
      await rig.controller.retrySave();

      expect(rig.controller.saveStatus, SaveStatus.saved);
      final Habit? stored = await rig.habits.inner.get('h1');
      expect(stored!.completedDays, <LocalDay>{_today});
      final Ghost? ghost = await rig.ghost.inner.get(HauntStorage.ghostKey);
      expect(ghost, rig.controller.haunting!.ghost);
    });

    test('retrySave that fails again stays in saveError', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      rig.habits.failPut = true;
      await rig.controller.toggle('h1');

      await rig.controller.retrySave();

      expect(rig.controller.saveStatus, SaveStatus.saveError);
    });
  });

  group('welcome back', () {
    final Ghost dead = Ghost(
      name: 'Boo',
      health: 0,
      lastSettledDay: _today.previous,
      resurrectionCount: 1,
    );

    test('is set on resurrection and cleared by dismissWelcome', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.seedGhost(dead);
      await rig.controller.load();
      expect(rig.controller.haunting!.ghost.isDead, isTrue);
      expect(rig.controller.welcomeBack, isNull);

      await rig.controller.toggle('h1');

      expect(rig.controller.haunting!.ghost.isDead, isFalse);
      expect(rig.controller.haunting!.ghost.resurrectionCount, 2);
      expect(rig.controller.welcomeBack, contains('Boo'));

      int notified = 0;
      rig.controller.addListener(() => notified++);
      rig.controller.dismissWelcome();
      expect(rig.controller.welcomeBack, isNull);
      expect(notified, 1);

      // Dismissing again is a no-op.
      rig.controller.dismissWelcome();
      expect(notified, 1);
    });

    test('is not set when the ghost is alive', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      await rig.controller.toggle('h1');
      expect(rig.controller.welcomeBack, isNull);
    });
  });

  group('dispose', () {
    test('does not notify listeners after dispose', () async {
      final _Rig rig = _Rig();
      await rig.seedHabit(_habit('h1'));
      await rig.controller.load();
      final Completer<void> gate = Completer<void>();
      rig.loggedGhost.gate = gate;
      int notified = 0;
      rig.controller.addListener(() => notified++);

      final Future<void> pending = rig.controller.toggle('h1');
      await Future<void>.delayed(Duration.zero);
      final int before = notified;
      rig.controller.dispose();
      gate.complete();
      await pending;

      expect(notified, before);
    });
  });
}
