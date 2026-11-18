import 'package:coffin_core/coffin_core.dart';

import '../domain/ghost.dart';
import '../domain/habit.dart';
import 'ghost_codec.dart';
import 'habit_codec.dart';

/// The two repositories Hauntagotchi saves its data in.
final class HauntStorage {
  /// Creates storage from already opened repositories.
  const HauntStorage({
    required this.habits,
    required this.ghost,
    required this.isPersistent,
  });

  /// Opens the habits and ghost boxes (schema version 1) with [opener].
  ///
  /// Never throws. A box that cannot be opened falls back to memory, and
  /// [isPersistent] is then false.
  static Future<HauntStorage> open(StorageOpener opener) async {
    final OpenedRepository<Habit> habits = await opener.open<Habit>(
      boxName: habitsBox,
      codec: const HabitCodec(),
      currentVersion: currentVersion,
    );
    final OpenedRepository<Ghost> ghost = await opener.open<Ghost>(
      boxName: ghostBox,
      codec: const GhostCodec(),
      currentVersion: currentVersion,
    );
    return HauntStorage(
      habits: habits.repository,
      ghost: ghost.repository,
      isPersistent: habits.isPersistent && ghost.isPersistent,
    );
  }

  /// Box name for habits.
  static const String habitsBox = 'hauntagotchi_habits';

  /// Box name for the ghost.
  static const String ghostBox = 'hauntagotchi_ghost';

  /// Key under which the single ghost record is stored.
  static const String ghostKey = 'ghost';

  /// Schema version of both boxes.
  static const int currentVersion = 1;

  /// Habit records, keyed by habit id.
  final RecordRepository<Habit> habits;

  /// The ghost record, stored under [ghostKey].
  final RecordRepository<Ghost> ghost;

  /// True only when both repositories save to disk.
  final bool isPersistent;

  /// Closes both repositories.
  Future<void> close() async {
    await habits.close();
    await ghost.close();
  }
}
