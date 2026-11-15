@TestOn('vm')
library;

import 'dart:io';

import 'package:coffin_core/src/storage/hive_raw_store.dart';
import 'package:coffin_core/src/storage/hive_record_repository.dart';
import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:coffin_core/src/storage/memory_record_repository.dart';
import 'package:coffin_core/src/storage/raw_store.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:coffin_core/src/storage/storage_opener.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_note.dart';

const String _marker = 'SECRET_MARKER_8731';

class _MarkerException implements Exception {
  @override
  String toString() => '_MarkerException: $_marker';
}

Future<void> _okInit() async {}

Future<RawStore> _memoryStore(String name, String? location) async =>
    MemoryRawStore();

void main() {
  const TestNoteCodec codec = TestNoteCodec();
  late List<StorageIssue> issues;

  setUp(() => issues = <StorageIssue>[]);

  StorageOpener opener({
    StorageInitializer initializer = _okInit,
    RawStoreOpener openStore = _memoryStore,
  }) => StorageOpener(
    initializer: initializer,
    openStore: openStore,
    reportIssue: issues.add,
  );

  test(
    'success with injected fakes is persistent and reports nothing',
    () async {
      final opened = await opener().open<TestNote>(
        boxName: 'notes',
        codec: codec,
        currentVersion: 1,
      );
      expect(opened.isPersistent, isTrue);
      expect(opened.repository, isA<HiveRecordRepository<TestNote>>());
      await opened.repository.put('a', const TestNote(title: 'x'));
      expect((await opened.repository.get('a'))?.title, 'x');
      expect(issues, isEmpty);
    },
  );

  test('passes box name and location to the store opener', () async {
    String? seenName;
    String? seenLocation;
    await opener(
      openStore: (name, location) async {
        seenName = name;
        seenLocation = location;
        return MemoryRawStore();
      },
    ).open<TestNote>(
      boxName: 'notes',
      codec: codec,
      currentVersion: 1,
      location: '/somewhere',
    );
    expect(seenName, 'notes');
    expect(seenLocation, '/somewhere');
  });

  Future<void> expectFallback(
    Future<dynamic> Function() run,
    String typeName,
  ) async {
    final opened = await run();
    expect(opened.isPersistent, isFalse);
    expect(opened.repository, isA<MemoryRecordRepository<TestNote>>());
    expect(issues, hasLength(1));
    expect(issues.single.kind, StorageIssueKind.fallbackToMemory);
    expect(issues.single.key, isNull);
    expect(issues.single.message, contains(typeName));
    expect(issues.single.message, isNot(contains(_marker)));
    // The fallback repository works.
    final repo = opened.repository;
    await repo.put('k', const TestNote(title: 'mem', count: 2));
    expect(await repo.get('k'), const TestNote(title: 'mem', count: 2));
    expect(await repo.getAll(), hasLength(1));
  }

  test('initializer failure falls back without leaking exception text', () {
    return expectFallback(
      () => opener(initializer: () async => throw _MarkerException())
          .open<TestNote>(boxName: 'notes', codec: codec, currentVersion: 1),
      '_MarkerException',
    );
  });

  test('box-open failure falls back without leaking exception text', () {
    return expectFallback(
      () => opener(openStore: (_, _) async => throw _MarkerException())
          .open<TestNote>(boxName: 'notes', codec: codec, currentVersion: 1),
      '_MarkerException',
    );
  });

  test('a synchronous throw from the initializer is also caught', () {
    return expectFallback(
      () => opener(initializer: () => throw _MarkerException())
          .open<TestNote>(boxName: 'notes', codec: codec, currentVersion: 1),
      '_MarkerException',
    );
  });

  for (final MapEntry<String, String> bad in <String, String>{
    'empty': '',
    'non-ASCII': 'Nötes',
    'too long': 'a' * 256,
  }.entries) {
    test('bad box name (${bad.key}) falls back and never opens a store', () {
      var opened = false;
      return expectFallback(
        () => opener(
          openStore: (name, location) async {
            opened = true;
            return MemoryRawStore();
          },
        ).open<TestNote>(boxName: bad.value, codec: codec, currentVersion: 1),
        'ArgumentError',
      ).then((_) => expect(opened, isFalse));
    });
  }

  test('a 255-character name is accepted', () async {
    final opened = await opener().open<TestNote>(
      boxName: 'A' * 255,
      codec: codec,
      currentVersion: 1,
    );
    expect(opened.isPersistent, isTrue);
    expect(issues, isEmpty);
  });

  test('a throwing reporter does not make open throw', () async {
    final StorageOpener throwing = StorageOpener(
      initializer: () async => throw _MarkerException(),
      reportIssue: (_) => throw StateError('reporter broke'),
    );
    final opened = await throwing.open<TestNote>(
      boxName: 'notes',
      codec: codec,
      currentVersion: 1,
    );
    expect(opened.isPersistent, isFalse);
  });

  test(
    'repositoryIssues defaults to reportIssue and can be overridden',
    () async {
      final seed = <String, String>{'bad': 'not json'};
      Future<RawStore> seeded(String n, String? l) async =>
          MemoryRawStore(seed);

      final defaulted = await opener(openStore: seeded)
          .open<TestNote>(boxName: 'notes', codec: codec, currentVersion: 1);
      await defaulted.repository.getAll();
      expect(issues.map((i) => i.kind), <StorageIssueKind>[
        StorageIssueKind.corruptRecord,
      ]);

      issues.clear();
      final separate = <StorageIssue>[];
      final overridden = await opener(openStore: seeded).open<TestNote>(
        boxName: 'notes',
        codec: codec,
        currentVersion: 1,
        repositoryIssues: separate.add,
      );
      await overridden.repository.getAll();
      expect(issues, isEmpty);
      expect(separate, hasLength(1));
    },
  );

  test(
    'the fallback issue goes to reportIssue, not repositoryIssues',
    () async {
      final separate = <StorageIssue>[];
      final opened =
          await opener(initializer: () async => throw _MarkerException())
              .open<TestNote>(
                boxName: 'notes',
                codec: codec,
                currentVersion: 1,
                repositoryIssues: separate.add,
              );
      expect(opened.isPersistent, isFalse);
      // Only the fallback issue goes to the opener's reporter.
      expect(issues, hasLength(1));
      expect(separate, isEmpty);
    },
  );

  test(
    'real store: unique name and temp dir as location, no Hive.init',
    () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'crypt_storage_opener_',
      );
      final String name =
          'crypt_t_opener_${DateTime.now().microsecondsSinceEpoch}';
      final StorageOpener real = StorageOpener(
        initializer: _okInit,
        openStore: HiveRawStore.open,
        reportIssue: issues.add,
      );
      var closed = false;
      final opened = await real.open<TestNote>(
        boxName: name,
        codec: codec,
        currentVersion: 1,
        location: dir.path,
      );
      try {
        expect(opened.isPersistent, isTrue);
        await opened.repository.put('a', const TestNote(title: 'real'));
        expect(await opened.repository.get('a'), const TestNote(title: 'real'));
        expect(issues, isEmpty);

        // Persistence: close, reopen the same name and location.
        await opened.repository.close();
        closed = true;
        final again = await real.open<TestNote>(
          boxName: name,
          codec: codec,
          currentVersion: 1,
          location: dir.path,
        );
        try {
          expect(again.isPersistent, isTrue);
          expect(
            await again.repository.get('a'),
            const TestNote(title: 'real'),
          );
        } finally {
          await again.repository.close();
        }
      } finally {
        if (!closed) await opened.repository.close();
        if (dir.existsSync()) await dir.delete(recursive: true);
      }
    },
  );
}
