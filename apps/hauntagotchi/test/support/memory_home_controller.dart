import 'package:coffin_core/coffin_core.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';
import 'package:hauntagotchi/src/ui/home_controller.dart';

import 'fake_clock.dart';

/// Builds a [HomeController] backed by in-memory repositories and a
/// [FakeClock], so route tests never touch Hive.
HomeController memoryHomeController() {
  return HomeController(
    clock: FakeClock(DateTime(2026, 3, 10, 9)),
    openStorage: () async => HauntStorage(
      habits: MemoryRecordRepository<Habit>(
        codec: const HabitCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
      ghost: MemoryRecordRepository<Ghost>(
        codec: const GhostCodec(),
        currentVersion: HauntStorage.currentVersion,
      ),
      isPersistent: true,
    ),
  );
}
