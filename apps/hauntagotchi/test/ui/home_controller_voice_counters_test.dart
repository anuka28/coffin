import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/domain/local_day.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';

import '../support/fake_clock.dart';
import '../support/throwing_record_repository.dart';

final DateTime _morning = DateTime(2026, 3, 10, 9);
final LocalDay _today = LocalDay(2026, 3, 10);

Ghost _ghost(int health) => Ghost(
  name: 'Boo',
  health: health,
  lastSettledDay: _today.previous,
  resurrectionCount: 1,
);

class _Rig {
  _Rig() : clock = FakeClock(_morning) {
    habits = ThrowingRecordRepository<Habit>(
      MemoryRecordRepository<Habit>(
        codec: const HabitCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
    );
    ghost = MemoryRecordRepository<Ghost>(
      codec: const GhostCodec(),
      currentVersion: HauntStorage.currentVersion,
    );
    controller = HomeController(
      clock: clock,
      openStorage: () async =>
          HauntStorage(habits: habits, ghost: ghost, isPersistent: true),
    );
  }

  final FakeClock clock;
  late final ThrowingRecordRepository<Habit> habits;
  late final MemoryRecordRepository<Ghost> ghost;
  late final HomeController controller;

  Future<void> ready(List<String> ids, int health) async {
    for (final String id in ids) {
      await habits.put(
        id,
        Habit(id: id, name: 'Habit $id', createdDay: _today),
      );
    }
    await ghost.put(HauntStorage.ghostKey, _ghost(health));
    await controller.load();
  }

  (int, int) get counts =>
      (controller.checkOffCount, controller.resurrectionCount);
}

void main() {
  test('both counters start at 0', () {
    final _Rig rig = _Rig();
    expect(rig.counts, (0, 0));
  });

  test('a completing toggle raises checkOffCount once', () async {
    final _Rig rig = _Rig();
    await rig.ready(<String>['h1'], 50);
    expect(rig.counts, (0, 0));
    await rig.controller.toggle('h1');
    expect(rig.counts, (1, 0));
  });

  test(
    'undo, add, rename, archive, retry and refresh change nothing',
    () async {
      final _Rig rig = _Rig();
      await rig.ready(<String>['h1', 'h2'], 50);
      await rig.controller.toggle('h1');
      expect(rig.counts, (1, 0));

      await rig.controller.toggle('h1'); // undo
      await rig.controller.addHabit('Stretch');
      await rig.controller.renameHabit('h2', 'Read');
      await rig.controller.archiveHabit('h2');
      await rig.controller.retrySave();
      await rig.controller.refresh();

      expect(rig.counts, (1, 0));
    },
  );

  test('a completing toggle that resurrects raises both', () async {
    final _Rig rig = _Rig();
    await rig.ready(<String>['h1'], 0);
    await rig.controller.toggle('h1');
    expect(rig.controller.haunting!.ghost.isDead, isFalse);
    expect(rig.counts, (1, 1));
  });

  test(
    'a ritual step that leaves the ghost dead raises only check-offs',
    () async {
      final _Rig rig = _Rig();
      await rig.ready(<String>['h1', 'h2'], 0);
      await rig.controller.toggle('h1');
      expect(rig.controller.haunting!.ghost.isDead, isTrue);
      expect(rig.counts, (1, 0));
    },
  );

  test('a rejected toggle changes neither counter', () async {
    final _Rig rig = _Rig();
    await rig.ready(<String>['h1'], 50);
    await rig.controller.toggle('missing');
    expect(rig.counts, (0, 0));
  });

  test('a failed save then a retry change neither counter', () async {
    final _Rig rig = _Rig();
    await rig.ready(<String>['h1'], 50);
    rig.habits.failPut = true;
    await rig.controller.addHabit('Stretch');
    rig.habits.failPut = false;
    await rig.controller.retrySave();
    expect(rig.counts, (0, 0));
  });

  test('a listener sees the new counters in the change notification', () async {
    final _Rig rig = _Rig();
    await rig.ready(<String>['h1'], 0);
    final List<(int, int)> seen = <(int, int)>[];
    rig.controller.addListener(() => seen.add(rig.counts));

    await rig.controller.toggle('h1');

    expect(seen, isNotEmpty);
    expect(seen.first, (1, 1));
  });
}
