@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/hive_raw_store.dart';
import 'package:coffin_core/src/storage/hive_record_repository.dart';
import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/migration_hook.dart';
import 'package:coffin_core/src/storage/raw_store.dart';
import 'package:coffin_core/src/storage/record_codec.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/hive_test_box.dart';
import 'support/repository_contract.dart';
import 'support/test_note.dart';

// Example tests for the persistent repository over a real Hive box. Every
// test owns a unique box and temp directory (see hive_test_box.dart).

const TestNoteCodec _codec = TestNoteCodec();

String _entry(int version, TestNote note) =>
    EnvelopeCodec.encode(version, _codec.encode(note));

/// A repository over a real box, with the box and issues exposed.
final class _Rig {
  _Rig._(this.hive, this.repo, this.issues);

  final HiveTestBox hive;
  final HiveRecordRepository<TestNote> repo;
  final List<StorageIssue> issues;

  /// Opens a box, puts [seed] straight into it, then builds the repository.
  static Future<_Rig> open({
    int version = 1,
    Map<String, String> seed = const <String, String>{},
    MigrationHook? migrate,
    RecordCodec<TestNote> codec = _codec,
    RawStore Function(RawStore)? wrap,
  }) async {
    final HiveTestBox hive = await openHiveTestBox();
    addTearDown(hive.dispose);
    for (final MapEntry<String, String> e in seed.entries) {
      await hive.box.put(e.key, e.value);
    }
    final List<StorageIssue> issues = <StorageIssue>[];
    RawStore store = HiveRawStore(hive.box);
    if (wrap != null) store = wrap(store);
    final HiveRecordRepository<TestNote> repo = HiveRecordRepository<TestNote>(
      store: store,
      codec: codec,
      currentVersion: version,
      migrate: migrate,
      reportIssue: issues.add,
    );
    addTearDown(repo.close);
    return _Rig._(hive, repo, issues);
  }

  /// The raw box contents, read straight from the box.
  Map<String, String> raw() => <String, String>{
    for (final dynamic k in hive.box.keys)
      k as String: hive.box.get(k) as String,
  };
}

/// Codec with replaceable encode, decode is the normal one.
final class _FnCodec implements RecordCodec<TestNote> {
  const _FnCodec(this._encode);

  final JsonMap Function(TestNote) _encode;

  @override
  JsonMap encode(TestNote record) => _encode(record);

  @override
  TestNote decode(JsonMap json) => _codec.decode(json);
}

/// Wraps a store; [failWrites] makes the next writes throw.
final class _FlakyStore implements RawStore {
  _FlakyStore(this._inner);

  final RawStore _inner;
  bool failWrites = false;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<List<String>> keys() => _inner.keys();

  @override
  Future<void> write(String key, String value) {
    if (failWrites) throw StateError('disk full');
    return _inner.write(key, value);
  }

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  Future<void> removeAll() => _inner.removeAll();

  @override
  Future<void> close() => _inner.close();
}

List<StorageEvent> _watch(Stream<StorageEvent> stream) {
  final List<StorageEvent> events = <StorageEvent>[];
  final StreamSubscription<StorageEvent> sub = stream.listen(events.add);
  addTearDown(sub.cancel);
  return events;
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  defineRepositoryContract('hive', () async {
    final HiveTestBox hive = await openHiveTestBox();
    final List<StorageIssue> issues = <StorageIssue>[];
    final HiveRecordRepository<TestNote> repo = HiveRecordRepository<TestNote>(
      store: HiveRawStore(hive.box),
      codec: _codec,
      currentVersion: 1,
      reportIssue: issues.add,
    );
    return RepoUnderTest(
      repository: repo,
      readRaw: () async => <String, String>{
        for (final dynamic k in hive.box.keys)
          k as String: hive.box.get(k) as String,
      },
      issues: issues,
      dispose: () async {
        try {
          await repo.close();
        } finally {
          await hive.dispose();
        }
      },
    );
  });

  group('HiveRecordRepository: encoding', () {
    test(
      'a rejected put leaves the raw box unchanged and emits nothing',
      () async {
        final List<JsonMap Function(TestNote)> unsafe =
            <JsonMap Function(TestNote)>[
              (_) => <String, Object?>{'x': double.nan},
              (_) => <String, Object?>{'x': 9007199254740992},
              (_) => <String, Object?>{'x': DateTime(2000)},
            ];
        for (final JsonMap Function(TestNote) encode in unsafe) {
          final Map<String, String> seed = <String, String>{
            'a': _entry(1, const TestNote(title: 'kept')),
          };
          final _Rig rig = await _Rig.open(seed: seed, codec: _FnCodec(encode));
          final List<StorageEvent> events = _watch(rig.repo.watch());
          await expectLater(
            rig.repo.put('a', const TestNote(title: 'new')),
            throwsArgumentError,
          );
          await expectLater(
            rig.repo.put('b', const TestNote(title: 'new')),
            throwsArgumentError,
          );
          await _settle();
          expect(events, isEmpty);
          expect(rig.raw(), seed);
        }
      },
    );
  });

  group('HiveRecordRepository: migration', () {
    const TestNote old = TestNote(title: 'old', count: 4);

    test('lower version with a hook is migrated and not rewritten', () async {
      final Map<String, String> seed = <String, String>{'a': _entry(1, old)};
      final List<int> froms = <int>[];
      final _Rig rig = await _Rig.open(
        version: 2,
        seed: seed,
        migrate: (int from, JsonMap data) {
          froms.add(from);
          return data;
        },
      );
      expect(await rig.repo.get('a'), old);
      expect(froms, <int>[1]);
      expect(rig.issues, isEmpty);
      expect(rig.raw(), seed);
    });

    test('lower version without a hook is skipped as unknownVersion', () async {
      final _Rig rig = await _Rig.open(
        version: 2,
        seed: <String, String>{'a': _entry(1, old)},
      );
      expect(await rig.repo.get('a'), isNull);
      expect(rig.issues.single.kind, StorageIssueKind.unknownVersion);
      expect(rig.issues.single.key, 'a');
    });

    test('higher version is skipped and the entry is untouched', () async {
      final Map<String, String> seed = <String, String>{'a': _entry(3, old)};
      final _Rig rig = await _Rig.open(version: 2, seed: seed);
      expect(await rig.repo.getAll(), isEmpty);
      expect(rig.issues.single.kind, StorageIssueKind.unknownVersion);
      expect(rig.raw(), seed);
    });

    test('a throwing hook is migrationFailed', () async {
      final _Rig rig = await _Rig.open(
        version: 2,
        seed: <String, String>{'a': _entry(1, old)},
        migrate: (int from, JsonMap data) => throw StateError('boom'),
      );
      expect(await rig.repo.get('a'), isNull);
      expect(rig.issues.single.kind, StorageIssueKind.migrationFailed);
    });

    test('put after migrate stores the current version', () async {
      final _Rig rig = await _Rig.open(
        version: 2,
        seed: <String, String>{'a': _entry(1, old)},
        migrate: (int from, JsonMap data) => data,
      );
      await rig.repo.put('a', (await rig.repo.get('a'))!);
      expect(EnvelopeCodec.parse(rig.raw()['a']!).version, 2);
    });
  });

  group('HiveRecordRepository: corrupt entries', () {
    const TestNote good = TestNote(title: 'good');

    test('corrupt values are skipped, reported and left in the box', () async {
      final Map<String, String> seed = <String, String>{
        'a-ok': _entry(1, good),
        'b-garbage': 'MARK not json {{',
        'c-array': '["MARK"]',
      };
      final _Rig rig = await _Rig.open(seed: seed);
      expect(await rig.repo.getAll(), <TestNote>[good]);
      expect(await rig.repo.get('b-garbage'), isNull);
      expect(
        rig.issues.map((StorageIssue i) => i.kind).toSet(),
        <StorageIssueKind>{StorageIssueKind.corruptRecord},
      );
      expect(rig.issues.map((StorageIssue i) => i.key), <String?>[
        'b-garbage',
        'c-array',
        'b-garbage',
      ]);
      for (final StorageIssue i in rig.issues) {
        expect(i.message, isNot(contains('MARK')));
      }
      expect(rig.raw(), seed);
    });

    test('a non-String value in the box is a corrupt record', () async {
      final _Rig rig = await _Rig.open(
        seed: <String, String>{'a': _entry(1, good)},
      );
      await rig.hive.box.put('num', 42);
      expect(await rig.repo.getAll(), <TestNote>[good]);
      expect(rig.issues.single.kind, StorageIssueKind.corruptRecord);
      expect(rig.issues.single.key, 'num');
    });

    test('put over a corrupt entry replaces it', () async {
      final _Rig rig = await _Rig.open(
        seed: <String, String>{'bad': 'not json'},
      );
      final List<StorageEvent> events = _watch(rig.repo.watch());
      await rig.repo.put('bad', const TestNote(title: 'fixed'));
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.put('bad')]);
      expect(await rig.repo.get('bad'), const TestNote(title: 'fixed'));
    });
  });

  group('HiveRecordRepository: closed', () {
    test('close closes the box and keeps the data on disk', () async {
      final _Rig rig = await _Rig.open();
      await rig.repo.put('a', const TestNote(title: 'kept'));
      await rig.repo.close();
      expect(rig.hive.box.isOpen, isFalse);
      final List<File> files = rig.hive.directory
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.hive'))
          .toList();
      expect(files, isNotEmpty);
      expect(files.any((File f) => f.lengthSync() > 0), isTrue);
      await expectLater(rig.repo.get('a'), throwsStateError);
    });
  });

  group('HiveRecordRepository: persistence', () {
    test('a record survives close and reopen at the same name', () async {
      final HiveTestBox hive = await openHiveTestBox();
      addTearDown(hive.dispose);
      const TestNote note = TestNote(
        title: 'lamp',
        count: 2,
        tags: <String>['x'],
      );
      final HiveRecordRepository<TestNote> first =
          HiveRecordRepository<TestNote>(
            store: HiveRawStore(hive.box),
            codec: _codec,
            currentVersion: 1,
          );
      await first.put('a', note);
      await first.close();
      expect(hive.box.isOpen, isFalse);

      final HiveRawStore reopened = await HiveRawStore.open(
        hive.name,
        hive.directory.path,
      );
      // Registered after hive.dispose, so it runs first.
      addTearDown(() async {
        await reopened.close();
      });
      final HiveRecordRepository<TestNote> second =
          HiveRecordRepository<TestNote>(
            store: reopened,
            codec: _codec,
            currentVersion: 1,
          );
      expect(await second.get('a'), note);
      expect(await second.getAll(), <TestNote>[note]);
    });
  });

  group('HiveRecordRepository: failing store', () {
    test(
      'a write that throws propagates, emits nothing and recovers',
      () async {
        late _FlakyStore flaky;
        final _Rig rig = await _Rig.open(
          wrap: (RawStore inner) => flaky = _FlakyStore(inner),
        );
        final List<StorageEvent> events = _watch(rig.repo.watch());
        await rig.repo.put('a', const TestNote(title: 'before'));

        flaky.failWrites = true;
        await expectLater(
          rig.repo.put('a', const TestNote(title: 'lost')),
          throwsStateError,
        );
        await _settle();
        expect(events, const <StorageEvent>[StorageEvent.put('a')]);
        expect(await rig.repo.get('a'), const TestNote(title: 'before'));

        flaky.failWrites = false;
        await rig.repo.put('b', const TestNote(title: 'after'));
        await _settle();
        expect(await rig.repo.get('b'), const TestNote(title: 'after'));
        expect(events, const <StorageEvent>[
          StorageEvent.put('a'),
          StorageEvent.put('b'),
        ]);
      },
    );
  });
}
