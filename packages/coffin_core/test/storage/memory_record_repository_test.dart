import 'dart:async';
import 'dart:convert';

import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/envelope_repository.dart';
import 'package:coffin_core/src/storage/issue_reporter.dart';
import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:coffin_core/src/storage/memory_record_repository.dart';
import 'package:coffin_core/src/storage/migration_hook.dart';
import 'package:coffin_core/src/storage/record_codec.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/storage_generators.dart';
import 'support/test_note.dart';

// Example tests for the memory repository. Pure: no dart:io, no hive_ce, so
// this file also runs on Chrome.
//
// The shared `defineRepositoryContract` body already runs against the memory
// engine in envelope_repository_test.dart (task 7.1), so it is NOT repeated
// here. This file covers the real `MemoryRecordRepository` class directly and
// the memory-only cases (migration, corrupt entries, encoding, raw-store
// checks). MemoryRecordRepository keeps its store private, so the checks that
// need raw contents run the same engine over a MemoryRawStore we hold.

const TestNoteCodec _codec = TestNoteCodec();

/// Envelope text for [note] stored at [version].
String _entry(int version, TestNote note) =>
    EnvelopeCodec.encode(version, _codec.encode(note));

/// An engine over a store we hold, so tests can read raw contents.
final class _Rig {
  _Rig({
    this.version = 1,
    Map<String, String> seed = const <String, String>{},
    MigrationHook? migrate,
    IssueReporter? reporter,
    RecordCodec<TestNote> codec = _codec,
  }) : store = MemoryRawStore(seed) {
    repo = EnvelopeRepository<TestNote>(
      store: store,
      codec: codec,
      currentVersion: version,
      migrate: migrate,
      reportIssue: reporter ?? issues.add,
    );
  }

  final int version;
  final MemoryRawStore store;
  final List<StorageIssue> issues = <StorageIssue>[];
  late final EnvelopeRepository<TestNote> repo;

  Future<Map<String, String>> raw() async => <String, String>{
    for (final String k in await store.keys()) k: (await store.read(k))!,
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

final class _Boom implements Exception {
  const _Boom();
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

MemoryRecordRepository<TestNote> _memory({
  Map<String, String> seed = const <String, String>{},
  int version = 1,
  IssueReporter? reporter,
}) {
  if (reporter == null) {
    return MemoryRecordRepository<TestNote>(
      codec: _codec,
      currentVersion: version,
      seed: seed,
    );
  }
  return MemoryRecordRepository<TestNote>(
    codec: _codec,
    currentVersion: version,
    seed: seed,
    reportIssue: reporter,
  );
}

void main() {
  group('MemoryRecordRepository: construction and seed', () {
    test('a new repository is empty', () async {
      final repo = _memory();
      expect(await repo.getAll(), isEmpty);
      expect(await repo.get('a'), isNull);
    });

    test('seeded entries are readable', () async {
      final repo = _memory(
        seed: <String, String>{'a': _entry(1, const TestNote(title: 'seeded'))},
      );
      expect(await repo.get('a'), const TestNote(title: 'seeded'));
    });

    test('later writes do not change the seed map', () async {
      final seed = <String, String>{'a': _entry(1, const TestNote(title: 's'))};
      final repo = _memory(seed: seed);
      await repo.put('b', const TestNote(title: 'b'));
      await repo.delete('a');
      expect(seed.keys, <String>['a']);
    });

    test('an invalid seed key throws ArgumentError', () {
      for (final String key in BoundaryKeys.invalid) {
        expect(
          () => _memory(seed: <String, String>{key: 'x'}),
          throwsArgumentError,
          reason: describeKey(key),
        );
      }
    });

    test('valid boundary keys are accepted as seed keys', () async {
      final repo = _memory(
        seed: <String, String>{
          for (final String k in BoundaryKeys.valid)
            k: _entry(1, TestNote(title: describeKey(k))),
        },
      );
      expect(await repo.getAll(), hasLength(BoundaryKeys.valid.length));
    });

    test('two repositories share no state', () async {
      final one = _memory();
      final two = _memory();
      await one.put('a', const TestNote(title: '1'));
      expect(await two.get('a'), isNull);
    });
  });

  group('MemoryRecordRepository: semantics', () {
    test('get on a missing key is null', () async {
      expect(await _memory().get('nope'), isNull);
    });

    test('put overwrites', () async {
      final repo = _memory();
      await repo.put('a', const TestNote(title: 'one'));
      await repo.put('a', const TestNote(title: 'two'));
      expect(await repo.get('a'), const TestNote(title: 'two'));
      expect(await repo.getAll(), hasLength(1));
    });

    test('delete on a missing key emits nothing', () async {
      final repo = _memory();
      final events = _watch(repo.watch());
      await repo.delete('a');
      await _settle();
      expect(events, isEmpty);
    });

    test('clear on an empty repository emits one clear', () async {
      final repo = _memory();
      final events = _watch(repo.watch());
      await repo.clear();
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.clear()]);
    });

    test('clear takes no key', () {
      final repo = _memory();
      expect(
        // ignore: avoid_dynamic_calls
        () => (repo as dynamic).clear('a'),
        throwsA(isA<Error>()),
      );
    });

    test('getAll orders by code unit', () async {
      final repo = _memory();
      for (final String k in <String>['b', 'a', 'B', 'aa', '~', '\u0000']) {
        await repo.put(k, TestNote(title: k));
      }
      final titles = (await repo.getAll()).map((n) => n.title).toList();
      expect(titles, <String>['\u0000', 'B', 'a', 'aa', 'b', '~']);
    });

    test('valid boundary keys round trip', () async {
      final repo = _memory();
      for (final String k in BoundaryKeys.valid) {
        await repo.put(k, TestNote(title: describeKey(k)));
      }
      for (final String k in BoundaryKeys.valid) {
        expect(await repo.get(k), TestNote(title: describeKey(k)));
      }
    });

    test('invalid keys throw ArgumentError from get, put, delete', () async {
      final repo = _memory();
      final events = _watch(repo.watch());
      for (final String k in BoundaryKeys.invalid) {
        final String why = describeKey(k);
        await expectLater(repo.get(k), throwsArgumentError, reason: why);
        await expectLater(
          repo.put(k, const TestNote(title: 'x')),
          throwsArgumentError,
          reason: why,
        );
        await expectLater(repo.delete(k), throwsArgumentError, reason: why);
      }
      await _settle();
      expect(events, isEmpty);
      expect(await repo.getAll(), isEmpty);
    });

    test('calls made without awaiting apply in call order', () async {
      final repo = _memory();
      final events = _watch(repo.watch());
      final p1 = repo.put('a', const TestNote(title: '1'));
      final bad = expectLater(
        repo.put('', const TestNote(title: 'x')),
        throwsArgumentError,
      );
      final p2 = repo.put('a', const TestNote(title: '2'));
      final g1 = repo.get('a');
      final d = repo.delete('a');
      final g2 = repo.get('a');
      final c = repo.clear();
      await Future.wait<void>(<Future<void>>[p1, bad, p2, d, c]);
      expect(await g1, const TestNote(title: '2'));
      expect(await g2, isNull);
      await _settle();
      expect(events, const <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.put('a'),
        StorageEvent.delete('a'),
        StorageEvent.clear(),
      ]);
    });
  });

  group('MemoryRecordRepository: watch', () {
    test('two listeners see the same events in order', () async {
      final repo = _memory();
      final first = _watch(repo.watch());
      final second = _watch(repo.watch());
      await repo.put('a', const TestNote(title: '1'));
      await repo.put('b', const TestNote(title: '2'));
      await repo.delete('a');
      await repo.clear();
      await _settle();
      const expected = <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.put('b'),
        StorageEvent.delete('a'),
        StorageEvent.clear(),
      ];
      expect(first, expected);
      expect(second, expected);
    });

    test('a late listener gets no replay', () async {
      final repo = _memory();
      await repo.put('a', const TestNote(title: '1'));
      await _settle();
      final late = _watch(repo.watch());
      await _settle();
      expect(late, isEmpty);
      await repo.delete('a');
      await _settle();
      expect(late, const <StorageEvent>[StorageEvent.delete('a')]);
    });

    test('the stream completes on close', () async {
      final repo = _memory();
      final done = repo.watch().toList();
      await repo.put('a', const TestNote(title: '1'));
      await repo.close();
      expect(await done, const <StorageEvent>[StorageEvent.put('a')]);
    });

    test('corrupt entries produce no stream error', () async {
      final repo = _memory(
        seed: <String, String>{'bad': 'not json'},
        reporter: (_) {},
      );
      final errors = <Object>[];
      final sub = repo.watch().listen((_) {}, onError: errors.add);
      addTearDown(sub.cancel);
      await repo.get('bad');
      await repo.getAll();
      await repo.put('bad', const TestNote(title: 'fixed'));
      await _settle();
      expect(errors, isEmpty);
    });
  });

  group('MemoryRecordRepository: close', () {
    test('a second close completes with the same future', () async {
      final repo = _memory();
      final first = repo.close();
      expect(repo.close(), same(first));
      await first;
      await repo.close();
    });

    test('each method throws StateError afterwards', () async {
      final repo = _memory();
      await repo.close();
      await expectLater(repo.get('a'), throwsStateError);
      await expectLater(repo.getAll(), throwsStateError);
      await expectLater(
        repo.put('a', const TestNote(title: '1')),
        throwsStateError,
      );
      await expectLater(repo.delete('a'), throwsStateError);
      await expectLater(repo.clear(), throwsStateError);
    });

    test('the closed check wins over the key check', () async {
      final repo = _memory();
      await repo.close();
      await expectLater(repo.get(''), throwsStateError);
      await expectLater(
        repo.put(BoundaryKeys.b4, const TestNote(title: '1')),
        throwsStateError,
      );
      await expectLater(repo.delete(BoundaryKeys.b9), throwsStateError);
    });

    test('watch after close completes with no events', () async {
      final repo = _memory();
      await repo.close();
      final events = await repo.watch().toList().timeout(
        const Duration(seconds: 5),
      );
      expect(events, isEmpty);
    });
  });

  group('memory drops its data', () {
    test('the store is empty after close', () async {
      final rig = _Rig();
      await rig.repo.put('a', const TestNote(title: '1'));
      await rig.repo.put('b', const TestNote(title: '2'));
      expect(await rig.raw(), hasLength(2));
      await rig.repo.close();
      expect(await rig.raw(), isEmpty);
    });

    test('calls made before close finish first', () async {
      final rig = _Rig();
      final events = _watch(rig.repo.watch());
      final put = rig.repo.put('a', const TestNote(title: '1'));
      final close = rig.repo.close();
      await put;
      await close;
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.put('a')]);
    });
  });

  group('migration', () {
    const old = TestNote(title: 'old', count: 4);

    test(
      'lower version with hook: called once with version and a copy',
      () async {
        final calls = <(int, JsonMap)>[];
        final rig = _Rig(
          version: 2,
          seed: <String, String>{'a': _entry(1, old)},
          migrate: (from, data) {
            calls.add((from, data));
            return data;
          },
        );
        expect(await rig.repo.get('a'), old);
        expect(calls, hasLength(1));
        expect(calls.single.$1, 1);
        expect(calls.single.$2, _codec.encode(old));
        expect(rig.issues, isEmpty);
      },
    );

    test('lower version without hook: skipped as unknownVersion', () async {
      final rig = _Rig(version: 2, seed: <String, String>{'a': _entry(1, old)});
      expect(await rig.repo.get('a'), isNull);
      expect(await rig.repo.getAll(), isEmpty);
      expect(rig.issues, hasLength(2));
      expect(rig.issues.first.kind, StorageIssueKind.unknownVersion);
      expect(rig.issues.first.key, 'a');
    });

    test('equal version: the hook is not called', () async {
      var calls = 0;
      final rig = _Rig(
        version: 2,
        seed: <String, String>{'a': _entry(2, old)},
        migrate: (from, data) {
          calls++;
          return data;
        },
      );
      expect(await rig.repo.get('a'), old);
      expect(calls, 0);
    });

    test('higher version: skipped and the entry is untouched', () async {
      var calls = 0;
      final seed = <String, String>{'a': _entry(3, old)};
      final rig = _Rig(
        version: 2,
        seed: seed,
        migrate: (from, data) {
          calls++;
          return data;
        },
      );
      expect(await rig.repo.get('a'), isNull);
      expect(await rig.repo.getAll(), isEmpty);
      expect(calls, 0);
      expect(rig.issues.map((i) => i.kind), <StorageIssueKind>[
        StorageIssueKind.unknownVersion,
        StorageIssueKind.unknownVersion,
      ]);
      expect(await rig.raw(), seed);
    });

    test('missing version is a corrupt record', () async {
      final rig = _Rig(
        seed: <String, String>{
          'a': jsonEncode(<String, Object?>{'data': _codec.encode(old)}),
        },
      );
      expect(await rig.repo.get('a'), isNull);
      expect(rig.issues.single.kind, StorageIssueKind.corruptRecord);
    });

    test('invalid versions are corrupt records and skip the hook', () async {
      var calls = 0;
      final data = _codec.encode(old);
      final bad = <Object?>[
        -1,
        1.5,
        '1',
        null,
        true,
        EnvelopeCodec.maxVersion + 1,
      ];
      final rig = _Rig(
        version: 2,
        seed: <String, String>{
          for (var i = 0; i < bad.length; i++)
            'k$i': jsonEncode(<String, Object?>{'v': bad[i], 'data': data}),
        },
        migrate: (from, d) {
          calls++;
          return d;
        },
      );
      expect(await rig.repo.getAll(), isEmpty);
      expect(calls, 0);
      expect(rig.issues, hasLength(bad.length));
      expect(
        rig.issues.every((i) => i.kind == StorageIssueKind.corruptRecord),
        isTrue,
      );
    });

    test('an integral double version 2.0 is version 2', () async {
      final rig = _Rig(
        version: 2,
        seed: <String, String>{
          'a': jsonEncode(<String, Object?>{
            'v': 2.0,
            'data': _codec.encode(old),
          }),
        },
      );
      expect(await rig.repo.get('a'), old);
    });

    test('a throwing hook is migrationFailed with no payload text', () async {
      const secret = TestNote(title: 'SECRETPAYLOAD');
      final rig = _Rig(
        version: 2,
        seed: <String, String>{'a': _entry(1, secret)},
        migrate: (from, data) => throw StateError('SECRETPAYLOAD boom'),
      );
      expect(await rig.repo.get('a'), isNull);
      expect(rig.issues.single.kind, StorageIssueKind.migrationFailed);
      expect(rig.issues.single.key, 'a');
      expect(rig.issues.single.message, isNot(contains('SECRETPAYLOAD')));
      expect(rig.issues.single.message, isNot(contains('boom')));
    });

    test('a hook that mutates its argument leaves stored data alone', () async {
      final seed = <String, String>{'a': _entry(1, old)};
      final titles = <Object?>[];
      final rig = _Rig(
        version: 2,
        seed: seed,
        migrate: (from, data) {
          titles.add(data['title']);
          data['title'] = 'mutated';
          (data['tags'] as List<Object?>).add('extra');
          return data;
        },
      );
      final first = await rig.repo.get('a');
      expect(first?.title, 'mutated');
      expect(await rig.raw(), seed);
      // The second read starts from the original stored data again.
      await rig.repo.get('a');
      expect(titles, <Object?>['old', 'old']);
      expect(await rig.raw(), seed);
    });

    test('reading never rewrites a migrated entry', () async {
      final seed = <String, String>{'a': _entry(1, old)};
      final rig = _Rig(version: 2, seed: seed, migrate: (from, data) => data);
      await rig.repo.get('a');
      await rig.repo.getAll();
      expect(await rig.raw(), seed);
    });

    test('put after migrate stores the current version', () async {
      final rig = _Rig(
        version: 2,
        seed: <String, String>{'a': _entry(1, old)},
        migrate: (from, data) => data,
      );
      final record = (await rig.repo.get('a'))!;
      await rig.repo.put('a', record);
      expect(EnvelopeCodec.parse((await rig.raw())['a']!).version, 2);
      expect(await rig.repo.get('a'), old);
    });
  });

  group('corrupt entries', () {
    const marker = 'PAYLOADMARK';
    const good = TestNote(title: 'good');

    Map<String, String> seed() => <String, String>{
      'a-ok': _entry(1, good),
      'b-garbage': '$marker not json {{',
      'c-array': '["$marker"]',
      'd-codec': EnvelopeCodec.encode(1, <String, Object?>{
        ..._codec.encode(good),
        'title': <Object?>[marker],
      }),
    };

    test(
      'get and getAll skip them, reporting one issue per entry per read',
      () async {
        final rig = _Rig(seed: seed());
        expect(await rig.repo.getAll(), <TestNote>[good]);
        expect(rig.issues.map((i) => i.key), <String?>[
          'b-garbage',
          'c-array',
          'd-codec',
        ]);
        expect(
          rig.issues.every((i) => i.kind == StorageIssueKind.corruptRecord),
          isTrue,
        );
        rig.issues.clear();
        expect(await rig.repo.getAll(), <TestNote>[good]);
        expect(rig.issues, hasLength(3));
        rig.issues.clear();
        expect(await rig.repo.get('b-garbage'), isNull);
        expect(await rig.repo.get('d-codec'), isNull);
        expect(await rig.repo.get('a-ok'), good);
        expect(rig.issues.map((i) => i.key), <String?>['b-garbage', 'd-codec']);
      },
    );

    test('reading leaves the entries unchanged', () async {
      final original = seed();
      final rig = _Rig(seed: original);
      await rig.repo.getAll();
      await rig.repo.get('c-array');
      expect(await rig.raw(), original);
    });

    test('put over a corrupt entry emits put and replaces it', () async {
      final rig = _Rig(seed: seed());
      final events = _watch(rig.repo.watch());
      await rig.repo.put('b-garbage', const TestNote(title: 'fixed'));
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.put('b-garbage')]);
      expect(await rig.repo.get('b-garbage'), const TestNote(title: 'fixed'));
    });

    test('delete of a corrupt entry emits delete', () async {
      final rig = _Rig(seed: seed());
      final events = _watch(rig.repo.watch());
      await rig.repo.delete('c-array');
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.delete('c-array')]);
      expect((await rig.raw()).containsKey('c-array'), isFalse);
    });

    test('a throwing reporter is swallowed', () async {
      var calls = 0;
      final rig = _Rig(
        seed: seed(),
        reporter: (_) {
          calls++;
          throw StateError('reporter broke');
        },
      );
      expect(await rig.repo.getAll(), <TestNote>[good]);
      expect(await rig.repo.get('b-garbage'), isNull);
      expect(calls, 4);
      await rig.repo.put('x', good);
      expect(await rig.repo.get('x'), good);
    });

    test('the default reporter works', () async {
      final repo = _memory(seed: seed());
      expect(await repo.getAll(), <TestNote>[good]);
      expect(await repo.get('d-codec'), isNull);
    });

    test('issue messages contain no payload marker', () async {
      final rig = _Rig(seed: seed());
      await rig.repo.getAll();
      expect(rig.issues, isNotEmpty);
      for (final StorageIssue issue in rig.issues) {
        expect(issue.message, isNot(contains(marker)));
        expect(issue.toString(), isNot(contains(marker)));
      }
    });
  });

  group('encoding', () {
    const kept = TestNote(title: 'kept');

    test(
      'a non-JSON-safe encode result throws ArgumentError and writes nothing',
      () async {
        final unsafe = <JsonMap Function(TestNote)>[
          (_) => <String, Object?>{'x': double.nan},
          (_) => <String, Object?>{'x': double.infinity},
          (_) => <String, Object?>{'x': 9007199254740992},
          (_) => <String, Object?>{'x': DateTime(2000)},
        ];
        for (final JsonMap Function(TestNote) encode in unsafe) {
          final seed = <String, String>{'a': _entry(1, kept)};
          final rig = _Rig(seed: seed, codec: _FnCodec(encode));
          final events = _watch(rig.repo.watch());
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
          expect(await rig.raw(), seed);
          expect(await rig.repo.get('a'), kept);
        }
      },
    );

    test(
      'an encode that throws propagates unchanged and writes nothing',
      () async {
        const boom = _Boom();
        final seed = <String, String>{'a': _entry(1, kept)};
        final rig = _Rig(seed: seed, codec: _FnCodec((_) => throw boom));
        final events = _watch(rig.repo.watch());
        Object? caught;
        try {
          await rig.repo.put('b', const TestNote(title: 'x'));
        } catch (e) {
          caught = e;
        }
        await _settle();
        expect(caught, same(boom));
        expect(events, isEmpty);
        expect(await rig.raw(), seed);
      },
    );

    test(
      'a record changed after put does not change what was stored',
      () async {
        final rig = _Rig();
        final tags = <String>['one'];
        final future = rig.repo.put('a', TestNote(title: 't', tags: tags));
        tags.add('two');
        await future;
        expect((await rig.repo.get('a'))?.tags, <String>['one']);
      },
    );
  });
}
