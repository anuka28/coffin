import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/envelope_repository.dart';
import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:coffin_core/src/storage/memory_record_repository.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repository_contract.dart';
import 'support/test_note.dart';

void main() {
  const TestNoteCodec codec = TestNoteCodec();

  test('put then get round trips', () async {
    final repo = MemoryRecordRepository<TestNote>(
      codec: codec,
      currentVersion: 1,
    );
    await repo.put('a', const TestNote(title: 'x', count: 3));
    expect(await repo.get('a'), const TestNote(title: 'x', count: 3));
  });

  test('getAll is sorted by key', () async {
    final repo = MemoryRecordRepository<TestNote>(
      codec: codec,
      currentVersion: 1,
    );
    await repo.put('b', const TestNote(title: 'B'));
    await repo.put('a', const TestNote(title: 'A'));
    final all = await repo.getAll();
    expect(all.map((n) => n.title), <String>['A', 'B']);
  });

  test('a corrupt seed is skipped and reported once per read', () async {
    final issues = <StorageIssue>[];
    final repo = MemoryRecordRepository<TestNote>(
      codec: codec,
      currentVersion: 1,
      seed: <String, String>{'bad': 'secret-payload{'},
      reportIssue: issues.add,
    );
    expect(await repo.getAll(), isEmpty);
    expect(await repo.get('bad'), isNull);
    expect(issues, hasLength(2));
    expect(issues.first.kind, StorageIssueKind.corruptRecord);
    expect(issues.first.key, 'bad');
    expect(issues.first.message, isNot(contains('secret')));
  });

  test('an older record is migrated with the hook', () async {
    final seen = <int>[];
    final repo = MemoryRecordRepository<TestNote>(
      codec: codec,
      currentVersion: 2,
      seed: <String, String>{
        'old': EnvelopeCodec.encode(1, <String, Object?>{'name': 'n'}),
      },
      migrate: (from, data) {
        seen.add(from);
        return <String, Object?>{
          'title': data['name'],
          'count': 0,
          'weight': null,
          'tags': <String>[],
          'extra': <String, Object?>{},
        };
      },
    );
    expect(await repo.get('old'), const TestNote(title: 'n'));
    expect(seen, <int>[1]);
  });

  test('close completes the stream and rejects later calls', () async {
    final repo = MemoryRecordRepository<TestNote>(
      codec: codec,
      currentVersion: 1,
    );
    final done = repo.watch().toList();
    final first = repo.close();
    expect(repo.close(), same(first));
    await first;
    expect(await done, isEmpty);
    expect(() => repo.get('a'), throwsStateError);
  });

  test('currentVersion outside range fails an assert', () {
    expect(
      () => MemoryRecordRepository<TestNote>(codec: codec, currentVersion: -1),
      throwsA(isA<AssertionError>()),
    );
  });

  defineRepositoryContract('memory', () async {
    final issues = <StorageIssue>[];
    final store = MemoryRawStore();
    // MemoryRecordRepository keeps its store private, and the contract needs
    // to read raw entries, so the shared engine runs over a store we hold.
    // MemoryRecordRepository is just this engine over a MemoryRawStore.
    final repo = EnvelopeRepository<TestNote>(
      store: store,
      codec: codec,
      currentVersion: 1,
      reportIssue: issues.add,
    );
    return RepoUnderTest(
      repository: repo,
      readRaw: () async => <String, String>{
        for (final k in await store.keys()) k: (await store.read(k))!,
      },
      issues: issues,
      dispose: repo.close,
    );
  });
}
