import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/ghost_codec.dart';
import 'package:hauntagotchi/src/data/habit_codec.dart';
import 'package:hauntagotchi/src/data/haunt_storage.dart';
import 'package:hauntagotchi/src/domain/ghost.dart';
import 'package:hauntagotchi/src/domain/habit.dart';

/// Builds a storage from memory repositories with the given flag.
HauntStorage _memoryStorage({required bool isPersistent}) {
  return HauntStorage(
    habits: MemoryRecordRepository<Habit>(
      codec: const HabitCodec(),
      currentVersion: HauntStorage.currentVersion,
    ),
    ghost: MemoryRecordRepository<Ghost>(
      codec: const GhostCodec(),
      currentVersion: HauntStorage.currentVersion,
    ),
    isPersistent: isPersistent,
  );
}

void main() {
  test('uses the agreed box names, key and version', () {
    expect(HauntStorage.habitsBox, 'hauntagotchi_habits');
    expect(HauntStorage.ghostBox, 'hauntagotchi_ghost');
    expect(HauntStorage.ghostKey, 'ghost');
    expect(HauntStorage.currentVersion, 1);
  });

  test('open asks the store for both boxes by name', () async {
    final List<String> requested = <String>[];
    final HauntStorage storage = await HauntStorage.open(
      StorageOpener(
        initializer: () async {},
        openStore: (String boxName, String? location) async {
          requested.add(boxName);
          throw StateError('fake store refuses');
        },
      ),
    );
    expect(requested, <String>['hauntagotchi_habits', 'hauntagotchi_ghost']);
    await storage.close();
  });

  test('falls back to memory and reports not persistent', () async {
    final List<StorageIssue> issues = <StorageIssue>[];
    final HauntStorage storage = await HauntStorage.open(
      StorageOpener(
        initializer: () async => throw StateError('no disk'),
        reportIssue: issues.add,
      ),
    );
    expect(storage.isPersistent, isFalse);
    expect(issues, hasLength(2));
    await storage.close();
  });

  test('fallback repositories still save and load records', () async {
    final HauntStorage storage = await HauntStorage.open(
      StorageOpener(initializer: () async => throw StateError('no disk')),
    );
    expect(await storage.habits.getAll(), isEmpty);
    expect(await storage.ghost.get(HauntStorage.ghostKey), isNull);
    await storage.close();
  });

  test('constructor keeps the given repositories and flag', () async {
    final HauntStorage persistent = _memoryStorage(isPersistent: true);
    final HauntStorage volatile = _memoryStorage(isPersistent: false);
    expect(persistent.isPersistent, isTrue);
    expect(volatile.isPersistent, isFalse);
    await persistent.close();
    await volatile.close();
  });

  test('close completes for both repositories', () async {
    final HauntStorage storage = _memoryStorage(isPersistent: false);
    await storage.close();
    expect(storage.habits.getAll(), throwsStateError);
    expect(storage.ghost.get(HauntStorage.ghostKey), throwsStateError);
  });
}
