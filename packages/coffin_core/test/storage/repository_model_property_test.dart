@TestOn('vm')
library;

import 'dart:async';

import 'package:coffin_core/src/storage/hive_raw_store.dart';
import 'package:coffin_core/src/storage/hive_record_repository.dart';
import 'package:coffin_core/src/storage/key_validator.dart';
import 'package:coffin_core/src/storage/memory_record_repository.dart';
import 'package:coffin_core/src/storage/record_repository.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:flutter_test/flutter_test.dart'
    show
        TestFailure,
        TestOn,
        expect,
        expectLater,
        greaterThan,
        group,
        isA,
        isNull,
        test,
        throwsA;
import 'package:glados/glados.dart' hide expect, expectLater, group, test;

import 'support/hive_test_box.dart';
import 'support/storage_generators.dart';
import 'support/test_note.dart';

const int _numRuns = 100;
const TestNoteCodec _codec = TestNoteCodec();

/// Counts body invocations and generated operations (Requirement 12.8).
int runsExecuted = 0;
int opsExecuted = 0;

/// What one mode left behind: final records and the events of each repository.
final class _Progress {
  int opIndex = 0;
  String phase = 'awaited mode';
}

final class _Outcome {
  const _Outcome(this.records, this.memoryEvents, this.hiveEvents);

  final List<TestNote> records;
  final List<StorageEvent> memoryEvents;
  final List<StorageEvent> hiveEvents;
}

/// The reference model: a plain map, written without the engine.
final class _Model {
  final Map<String, TestNote> map = <String, TestNote>{};
  final List<StorageEvent> events = <StorageEvent>[];

  /// Applies [op]. Returns true when the op was accepted, false when its key
  /// is invalid (state and events unchanged).
  bool apply(Op op) {
    switch (op) {
      case PutOp(:final String key, :final TestNote note):
        if (!KeyValidator.isValid(key)) return false;
        map[key] = note;
        events.add(StorageEvent.put(key));
      case DeleteOp(:final String key):
        if (!KeyValidator.isValid(key)) return false;
        if (map.remove(key) != null) events.add(StorageEvent.delete(key));
      case ClearOp():
        map.clear();
        events.add(const StorageEvent.clear());
    }
    return true;
  }

  List<TestNote> get all {
    final List<String> keys = map.keys.toList()
      ..sort((String a, String b) => a.compareTo(b));
    return <TestNote>[for (final String k in keys) map[k]!];
  }
}

Future<void> _applyOp(RecordRepository<TestNote> repo, Op op) => switch (op) {
  PutOp(:final String key, :final TestNote note) => repo.put(key, note),
  DeleteOp(:final String key) => repo.delete(key),
  ClearOp() => repo.clear(),
};

Iterable<String> _keysOf(Op op) => switch (op) {
  PutOp(:final String key) => <String>[key],
  DeleteOp(:final String key) => <String>[key],
  ClearOp() => const <String>[],
};

/// Asserts get for every touched key and getAll agree with the model.
Future<void> _checkState(
  _Model model,
  Set<String> touched,
  RecordRepository<TestNote> memory,
  RecordRepository<TestNote> hive,
) async {
  for (final String key in touched) {
    if (!KeyValidator.isValid(key)) {
      await expectLater(memory.get(key), throwsA(isA<ArgumentError>()));
      await expectLater(hive.get(key), throwsA(isA<ArgumentError>()));
      continue;
    }
    final TestNote? expected = model.map[key];
    expect(await memory.get(key), expected, reason: 'memory get($key)');
    expect(await hive.get(key), expected, reason: 'hive get($key)');
  }
  expect(await memory.getAll(), model.all, reason: 'memory getAll');
  expect(await hive.getAll(), model.all, reason: 'hive getAll');
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Runs [ops] on a fresh trio. Owns and disposes all of its state.
Future<_Outcome> _runMode(
  List<Op> ops,
  _Progress progress, {
  required bool awaited,
}) async {
  final HiveTestBox helper = await openHiveTestBox();
  final MemoryRecordRepository<TestNote> memory = MemoryRecordRepository(
    codec: _codec,
    currentVersion: 1,
  );
  final HiveRecordRepository<TestNote> hive = HiveRecordRepository(
    store: HiveRawStore(helper.box),
    codec: _codec,
    currentVersion: 1,
  );
  final _Model model = _Model();
  final List<StorageEvent> memoryEvents = <StorageEvent>[];
  final List<StorageEvent> hiveEvents = <StorageEvent>[];
  final StreamSubscription<StorageEvent> memorySub = memory.watch().listen(
    memoryEvents.add,
  );
  final StreamSubscription<StorageEvent> hiveSub = hive.watch().listen(
    hiveEvents.add,
  );
  try {
    final Set<String> touched = <String>{};
    if (awaited) {
      for (final Op op in ops) {
        progress.opIndex += 1;
        touched.addAll(_keysOf(op));
        final bool accepted = model.apply(op);
        if (accepted) {
          await _applyOp(memory, op);
          await _applyOp(hive, op);
        } else {
          await expectLater(
            _applyOp(memory, op),
            throwsA(isA<ArgumentError>()),
          );
          await expectLater(_applyOp(hive, op), throwsA(isA<ArgumentError>()));
        }
        await _checkState(model, touched, memory, hive);
        await _settle();
        expect(memoryEvents, model.events, reason: 'memory events');
        expect(hiveEvents, model.events, reason: 'hive events');
      }
    } else {
      // Fire every call first, then await them together.
      final List<Future<Object?>> memoryResults = <Future<Object?>>[];
      final List<Future<Object?>> hiveResults = <Future<Object?>>[];
      final List<bool> accepted = <bool>[];
      for (final Op op in ops) {
        touched.addAll(_keysOf(op));
        accepted.add(model.apply(op));
        memoryResults.add(
          _applyOp(
            memory,
            op,
          ).then<Object?>((_) => null, onError: (Object e) => e),
        );
        hiveResults.add(
          _applyOp(
            hive,
            op,
          ).then<Object?>((_) => null, onError: (Object e) => e),
        );
      }
      final List<Object?> memoryOutcomes = await Future.wait(memoryResults);
      final List<Object?> hiveOutcomes = await Future.wait(hiveResults);
      for (int i = 0; i < ops.length; i++) {
        for (final List<Object?> outcomes in <List<Object?>>[
          memoryOutcomes,
          hiveOutcomes,
        ]) {
          if (accepted[i]) {
            expect(outcomes[i], isNull, reason: 'op $i should succeed');
          } else {
            expect(outcomes[i], isA<ArgumentError>(), reason: 'op $i');
          }
        }
      }
      await _checkState(model, touched, memory, hive);
      await _settle();
      expect(memoryEvents, model.events, reason: 'memory events');
      expect(hiveEvents, model.events, reason: 'hive events');
    }
    return _Outcome(
      model.all,
      List<StorageEvent>.of(memoryEvents),
      List<StorageEvent>.of(hiveEvents),
    );
  } finally {
    await memorySub.cancel();
    await hiveSub.cancel();
    await memory.close();
    await hive.close();
    await helper.dispose();
  }
}

void main() {
  group('Repository model property', () {
    // Feature: crypt-storage, Property 6: Memory, Hive and a plain Map agree
    // Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.7, 2.8, 2.9, 2.10,
    // 3.2, 3.3, 3.4, 4.2, 4.3, 4.4, 7.7, 8.1, 12.3, 12.4, 12.5, 12.6, 12.7,
    // 12.8, 12.9, 12.10, 12.11, 13.1, 13.2, 13.3
    Glados(anyOps(), ExploreConfig(numRuns: _numRuns)).test(
      'memory, Hive and a plain Map agree, awaited and fired together',
      (List<Op> ops) async {
        runsExecuted += 1;
        opsExecuted += ops.length;
        final _Progress progress = _Progress();
        try {
          final _Outcome awaitedOutcome = await _runMode(
            ops,
            progress,
            awaited: true,
          );
          progress
            ..phase = 'fire-all mode'
            ..opIndex = ops.length;
          final _Outcome firedOutcome = await _runMode(
            ops,
            progress,
            awaited: false,
          );
          progress.phase = 'comparing modes';
          expect(firedOutcome.records, awaitedOutcome.records);
          expect(firedOutcome.memoryEvents, awaitedOutcome.memoryEvents);
          expect(firedOutcome.hiveEvents, awaitedOutcome.hiveEvents);
        } catch (e) {
          throw TestFailure(
            'Mismatch in ${progress.phase} after op ${progress.opIndex} of '
            '$ops: $e',
          );
        }
      },
    );

    test('model test really ran', () {
      expect(runsExecuted, _numRuns);
      expect(opsExecuted, greaterThan(0));
    });
  });
}
