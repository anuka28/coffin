import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction_kind.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';

import '../support/fake_clock.dart';

/// Keeps a log of every key written through it.
final class _RecordingRepository<T> implements RecordRepository<T> {
  _RecordingRepository(this.inner, this.label, this.log);

  final RecordRepository<T> inner;
  final String label;
  final List<String> log;

  @override
  Future<void> put(String key, T record) {
    log.add('$label:$key');
    return inner.put(key, record);
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

Habit _habit(String id) => Habit(id: id, name: 'Habit $id', createdDay: _today);

class _Rig {
  _Rig() : clock = FakeClock(_morning) {
    habits = MemoryRecordRepository<Habit>(
      codec: const HabitCodec(),
      currentVersion: HauntStorage.currentVersion,
    );
    ghost = MemoryRecordRepository<Ghost>(
      codec: const GhostCodec(),
      currentVersion: HauntStorage.currentVersion,
    );
    controller = HomeController(
      clock: clock,
      openStorage: () async => HauntStorage(
        habits: _RecordingRepository<Habit>(habits, 'habit', log),
        ghost: _RecordingRepository<Ghost>(ghost, 'ghost', log),
        isPersistent: true,
      ),
    );
  }

  final FakeClock clock;
  final List<String> log = <String>[];
  late final MemoryRecordRepository<Habit> habits;
  late final MemoryRecordRepository<Ghost> ghost;
  late final HomeController controller;

  Future<void> seed(List<String> ids, {Ghost? ghostRecord}) async {
    for (final String id in ids) {
      await habits.put(id, _habit(id));
    }
    if (ghostRecord != null) {
      await ghost.put(HauntStorage.ghostKey, ghostRecord);
    }
  }
}

Ghost _ghost(int health) => Ghost(
  name: 'Boo',
  health: health,
  lastSettledDay: _today.previous,
  resurrectionCount: 1,
);

void main() {
  group('GhostReaction', () {
    test('has value equality and a matching hash code', () {
      const GhostReaction a = GhostReaction(GhostReactionKind.fed, 1);
      const GhostReaction b = GhostReaction(GhostReactionKind.fed, 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const GhostReaction(GhostReactionKind.rising, 1)));
      expect(a, isNot(const GhostReaction(GhostReactionKind.fed, 2)));
    });
  });

  group('fed', () {
    for (final int health in <int>[100, 60, 1]) {
      test('follows a check-off at Health $health', () async {
        final _Rig rig = _Rig();
        await rig.seed(<String>['h1'], ghostRecord: _ghost(health));
        await rig.controller.load();
        expect(rig.controller.reaction, isNull);

        await rig.controller.toggle('h1');

        expect(
          rig.controller.reaction,
          const GhostReaction(GhostReactionKind.fed, 1),
        );
      });
    }
  });

  group('no event', () {
    Future<_Rig> ready() async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1', 'h2'], ghostRecord: _ghost(100));
      await rig.controller.load();
      return rig;
    }

    test('after load and refresh', () async {
      final _Rig rig = await ready();
      await rig.controller.refresh();
      expect(rig.controller.reaction, isNull);
    });

    test('for undo', () async {
      final _Rig rig = await ready();
      await rig.controller.toggle('h1');
      final GhostReaction? before = rig.controller.reaction;
      await rig.controller.toggle('h1');
      expect(rig.controller.reaction, before);
      expect(before!.key, 1);
    });

    test('for a rejected toggle', () async {
      final _Rig rig = await ready();
      await rig.controller.toggle('missing');
      expect(rig.controller.reaction, isNull);
    });

    test('for a tap on a day change', () async {
      final _Rig rig = await ready();
      rig.clock.advance(const Duration(days: 1));
      await rig.controller.toggle('h1');
      expect(rig.controller.reaction, isNull);
    });

    test('for add, rename and archive', () async {
      final _Rig rig = await ready();
      await rig.controller.addHabit('Stretch');
      await rig.controller.renameHabit('h1', 'Read');
      await rig.controller.archiveHabit('h2');
      expect(rig.controller.reaction, isNull);
    });

    test('for a Ritual step that leaves the ghost dead', () async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1', 'h2'], ghostRecord: _ghost(0));
      await rig.controller.load();
      expect(rig.controller.haunting!.ghost.isDead, isTrue);

      await rig.controller.toggle('h1');

      expect(rig.controller.haunting!.ghost.isDead, isTrue);
      expect(rig.controller.reaction, isNull);

      // The key counter did not advance for the skipped step.
      await rig.controller.toggle('h2');
      expect(
        rig.controller.reaction,
        const GhostReaction(GhostReactionKind.rising, 1),
      );
    });
  });

  group('rising', () {
    test('follows a Ritual completion and replaces fed', () async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1'], ghostRecord: _ghost(0));
      await rig.controller.load();

      await rig.controller.toggle('h1');

      expect(rig.controller.haunting!.ghost.isDead, isFalse);
      expect(rig.controller.reaction!.kind, GhostReactionKind.rising);
      expect(rig.controller.reaction!.key, 1);
    });
  });

  group('keys', () {
    test('start at 1 and strictly increase over check-offs', () async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1', 'h2', 'h3'], ghostRecord: _ghost(50));
      await rig.controller.load();
      final List<int> keys = <int>[];
      for (final String id in <String>['h1', 'h2', 'h1', 'h3', 'h1']) {
        await rig.controller.toggle(id);
        final GhostReaction? r = rig.controller.reaction;
        if (r != null && (keys.isEmpty || keys.last != r.key)) {
          keys.add(r.key);
        }
      }
      // h1 on, h2 on, h1 off (no event), h3 on, h1 on again: four events.
      expect(keys, <int>[1, 2, 3, 4]);
      expect(_Rig().controller.reaction, isNull);
    });
  });

  group('notification', () {
    test(
      'is sent once per action with haunting and reaction together',
      () async {
        final _Rig rig = _Rig();
        await rig.seed(<String>['h1'], ghostRecord: _ghost(50));
        await rig.controller.load();
        final List<(bool, GhostReaction?)> seen = <(bool, GhostReaction?)>[];
        rig.controller.addListener(() {
          final bool done =
              rig.controller.haunting!.book.completedCountOn(_today) == 1;
          seen.add((done, rig.controller.reaction));
        });

        await rig.controller.toggle('h1');

        // First notification: the change itself. The rest are save-status ones.
        expect(seen.first.$1, isTrue);
        expect(seen.first.$2, const GhostReaction(GhostReactionKind.fed, 1));
        expect(
          seen.where((e) => e.$2 != null && e.$2!.key == 1).length,
          seen.length,
        );
      },
    );

    test('is not sent after dispose, and no event is made', () async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1'], ghostRecord: _ghost(50));
      await rig.controller.load();
      int notified = 0;
      rig.controller.addListener(() => notified++);
      rig.controller.dispose();

      await expectLater(rig.controller.toggle('h1'), completes);

      expect(notified, 0);
      expect(rig.controller.reaction, isNull);
    });
  });

  group('storage', () {
    test('events are never written', () async {
      final _Rig rig = _Rig();
      await rig.seed(<String>['h1', 'h2'], ghostRecord: _ghost(50));
      await rig.controller.load();
      rig.log.clear();

      await rig.controller.toggle('h1');
      await rig.controller.toggle('h2');
      await rig.controller.toggle('h1');

      expect(rig.log.toSet(), <String>{
        'habit:h1',
        'habit:h2',
        'ghost:${HauntStorage.ghostKey}',
      });
      final Ghost? stored = await rig.ghost.get(HauntStorage.ghostKey);
      expect(stored, rig.controller.haunting!.ghost);
      final List<Habit> habits = await rig.habits.getAll();
      expect(
        habits.map((Habit h) => h.completedDays.length).toList()..sort(),
        <int>[0, 1],
      );
      expect(rig.controller.reaction!.key, 2);
    });
  });
}
