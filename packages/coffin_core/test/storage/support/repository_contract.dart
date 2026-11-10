import 'dart:async';

import 'package:coffin_core/src/storage/record_repository.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_generators.dart';
import 'test_note.dart';

// Pure support code: no dart:io, no hive_ce, and no concrete repository. It is
// written against the `RecordRepository` interface only, so the memory
// repository (task 7.2) and a Hive-backed one over a real box (task 10.2) both
// run the same body.

/// Everything one contract test needs from a repository factory.
final class RepoUnderTest {
  /// Creates the bundle.
  const RepoUnderTest({
    required this.repository,
    required this.readRaw,
    required this.issues,
    required this.dispose,
  });

  /// The repository being tested, using `TestNoteCodec` and version 1.
  final RecordRepository<TestNote> repository;

  /// Reads the raw store: every key and its stored string, as they are right
  /// now. May fail after the repository was closed (a memory store is empty
  /// then), so the contract only calls it while the repository is open.
  final Future<Map<String, String>> Function() readRaw;

  /// Every `StorageIssue` the repository reported, in order. The factory wires
  /// this list to the repository's issue reporter.
  final List<StorageIssue> issues;

  /// Releases everything (closes the repository and, for Hive, the box, then
  /// deletes the temp directory). Must be safe to call after the repository
  /// was closed and safe to call twice.
  final Future<void> Function() dispose;
}

/// Defines the shared repository tests under a group named [label].
///
/// [create] runs once per test and must return a fresh, empty, open
/// repository that shares no state with earlier ones (a unique box name and
/// directory for Hive). The contract disposes each bundle in `addTearDown`.
///
/// Call this from `main()` of a test file:
///
/// ```dart
/// defineRepositoryContract('memory', () async {
///   final issues = <StorageIssue>[];
///   final store = MemoryRawStore();
///   return RepoUnderTest(
///     repository: MemoryRecordRepository<TestNote>(...),
///     readRaw: () async => {for (final k in await store.keys()) k: (await store.read(k))!},
///     issues: issues,
///     dispose: () async {},
///   );
/// });
/// ```
void defineRepositoryContract(
  String label,
  Future<RepoUnderTest> Function() create,
) {
  Future<RepoUnderTest> open() async {
    final RepoUnderTest under = await create();
    addTearDown(under.dispose);
    return under;
  }

  group('repository contract ($label)', () {
    test('get on a missing key is null', () async {
      final RepoUnderTest u = await open();
      expect(await u.repository.get('a'), isNull);
      expect(await u.repository.getAll(), isEmpty);
    });

    test('put then get returns an equal record; raw holds the key', () async {
      final RepoUnderTest u = await open();
      const TestNote note = TestNote(
        title: 'lamp',
        count: 2,
        weight: 1.5,
        tags: <String>['x'],
        extra: <String, Object?>{
          'n': <Object?>[1, 2.5, null],
        },
      );
      await u.repository.put('a', note);
      expect(await u.repository.get('a'), note);
      expect((await u.readRaw()).keys, <String>['a']);
    });

    test('overwrite replaces the record and emits put each time', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      await u.repository.put('a', const TestNote(title: 'one'));
      await u.repository.put('a', const TestNote(title: 'two'));
      await u.repository.put('a', const TestNote(title: 'two'));
      await _settle();
      expect(await u.repository.get('a'), const TestNote(title: 'two'));
      expect(await u.repository.getAll(), hasLength(1));
      expect((await u.readRaw()).keys, <String>['a']);
      expect(events, const <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.put('a'),
        StorageEvent.put('a'),
      ]);
    });

    test('getAll is ordered by key, compared by code unit', () async {
      final RepoUnderTest u = await open();
      final List<String> keys = <String>[
        'b',
        'aa',
        'a',
        'B',
        'a/b..c d',
        '\u0000',
        'x\u007F',
      ];
      for (final String key in keys) {
        await u.repository.put(key, TestNote(title: key));
      }
      final List<String> expected = List<String>.of(keys)..sort();
      final List<TestNote> all = await u.repository.getAll();
      expect(all.map((TestNote n) => n.title).toList(), expected);
    });

    test('delete removes the record and emits delete', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      await u.repository.put('a', const TestNote(title: 'one'));
      await u.repository.delete('a');
      await _settle();
      expect(await u.repository.get('a'), isNull);
      expect(await u.readRaw(), isEmpty);
      expect(events, const <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.delete('a'),
      ]);
    });

    test('delete of a missing key completes and emits nothing', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      await u.repository.delete('a');
      await _settle();
      expect(events, isEmpty);
    });

    test('clear removes everything and emits one clear', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      await u.repository.put('a', const TestNote(title: 'one'));
      await u.repository.put('b', const TestNote(title: 'two'));
      await u.repository.clear();
      await _settle();
      expect(await u.repository.getAll(), isEmpty);
      expect(await u.readRaw(), isEmpty);
      expect(events.last, const StorageEvent.clear());
      expect(events.where((StorageEvent e) => e.key == null), hasLength(1));
    });

    test('clear on an empty repository emits one clear', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      await u.repository.clear();
      await _settle();
      expect(events, const <StorageEvent>[StorageEvent.clear()]);
    });

    test('valid boundary keys round trip', () async {
      final RepoUnderTest u = await open();
      for (final String key in BoundaryKeys.valid) {
        await u.repository.put(key, TestNote(title: describeKey(key)));
      }
      for (final String key in BoundaryKeys.valid) {
        expect(
          await u.repository.get(key),
          TestNote(title: describeKey(key)),
          reason: describeKey(key),
        );
      }
      expect((await u.readRaw()).keys.toSet(), BoundaryKeys.valid.toSet());
      expect(await u.repository.getAll(), hasLength(BoundaryKeys.valid.length));
    });

    test(
      'invalid keys throw ArgumentError; nothing changes or is emitted',
      () async {
        final RepoUnderTest u = await open();
        await u.repository.put('a', const TestNote(title: 'keep'));
        final Map<String, String> before = await u.readRaw();
        final List<StorageEvent> events = _collect(u.repository);
        for (final String key in BoundaryKeys.invalid) {
          final String reason = describeKey(key);
          await expectLater(
            u.repository.get(key),
            throwsArgumentError,
            reason: 'get $reason',
          );
          await expectLater(
            u.repository.put(key, const TestNote(title: 'no')),
            throwsArgumentError,
            reason: 'put $reason',
          );
          await expectLater(
            u.repository.delete(key),
            throwsArgumentError,
            reason: 'delete $reason',
          );
        }
        await _settle();
        expect(events, isEmpty);
        expect(await u.readRaw(), before);
        expect(await u.repository.getAll(), const <TestNote>[
          TestNote(title: 'keep'),
        ]);
      },
    );

    test('watch: two listeners see the same events in order', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> first = _collect(u.repository);
      final List<StorageEvent> second = _collect(u.repository);
      await u.repository.put('a', const TestNote(title: '1'));
      await u.repository.put('b', const TestNote(title: '2'));
      await u.repository.delete('a');
      await u.repository.clear();
      await _settle();
      const List<StorageEvent> expected = <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.put('b'),
        StorageEvent.delete('a'),
        StorageEvent.clear(),
      ];
      expect(first, expected);
      expect(second, expected);
    });

    test('watch: a late listener gets no replay', () async {
      final RepoUnderTest u = await open();
      await u.repository.put('a', const TestNote(title: '1'));
      await _settle();
      final List<StorageEvent> lateEvents = _collect(u.repository);
      await _settle();
      expect(lateEvents, isEmpty);
      await u.repository.put('b', const TestNote(title: '2'));
      await _settle();
      expect(lateEvents, const <StorageEvent>[StorageEvent.put('b')]);
    });

    test('calls made without awaiting apply in call order', () async {
      final RepoUnderTest u = await open();
      final List<StorageEvent> events = _collect(u.repository);
      final Future<void> p1 = u.repository.put('a', const TestNote(title: '1'));
      final Future<void> p2 = u.repository.put('a', const TestNote(title: '2'));
      final Future<void> d1 = u.repository.delete('b');
      final Future<void> p3 = u.repository.put('b', const TestNote(title: '3'));
      final Future<TestNote?> g1 = u.repository.get('a');
      final Future<void> d2 = u.repository.delete('a');
      final Future<TestNote?> g2 = u.repository.get('a');
      await Future.wait<void>(<Future<void>>[p1, p2, d1, p3, d2]);
      expect(await g1, const TestNote(title: '2'));
      expect(await g2, isNull);
      expect(await u.repository.get('b'), const TestNote(title: '3'));
      await _settle();
      expect(events, const <StorageEvent>[
        StorageEvent.put('a'),
        StorageEvent.put('a'),
        StorageEvent.put('b'),
        StorageEvent.delete('a'),
      ]);
    });

    test('normal use reports no issues', () async {
      final RepoUnderTest u = await open();
      await u.repository.put('a', const TestNote(title: '1'));
      await u.repository.get('a');
      await u.repository.getAll();
      await u.repository.delete('a');
      await u.repository.clear();
      expect(u.issues, isEmpty);
    });

    group('close', () {
      test('every method throws StateError afterwards', () async {
        final RepoUnderTest u = await open();
        await u.repository.close();
        await expectLater(u.repository.get('a'), throwsStateError);
        await expectLater(u.repository.getAll(), throwsStateError);
        await expectLater(
          u.repository.put('a', const TestNote(title: '1')),
          throwsStateError,
        );
        await expectLater(u.repository.delete('a'), throwsStateError);
        await expectLater(u.repository.clear(), throwsStateError);
      });

      test('the closed check wins over the key check', () async {
        final RepoUnderTest u = await open();
        await u.repository.close();
        await expectLater(u.repository.get(''), throwsStateError);
        await expectLater(
          u.repository.put('', const TestNote(title: '1')),
          throwsStateError,
        );
        await expectLater(u.repository.delete(''), throwsStateError);
      });

      test('a second close completes', () async {
        final RepoUnderTest u = await open();
        await u.repository.close();
        await u.repository.close();
      });

      test('watch completes on close and gets no event for it', () async {
        final RepoUnderTest u = await open();
        final List<StorageEvent> events = <StorageEvent>[];
        bool done = false;
        final StreamSubscription<StorageEvent> sub = u.repository
            .watch()
            .listen(events.add, onDone: () => done = true);
        addTearDown(sub.cancel);
        await u.repository.put('a', const TestNote(title: '1'));
        await u.repository.close();
        await _settle();
        expect(done, isTrue);
        expect(events, const <StorageEvent>[StorageEvent.put('a')]);
      });

      test('watch after close is an empty stream that completes', () async {
        final RepoUnderTest u = await open();
        await u.repository.close();
        final List<StorageEvent> events = await u.repository
            .watch()
            .toList()
            .timeout(const Duration(seconds: 5));
        expect(events, isEmpty);
      });

      test('calls made before close still finish', () async {
        final RepoUnderTest u = await open();
        final List<StorageEvent> events = _collect(u.repository);
        final Future<void> put = u.repository.put(
          'a',
          const TestNote(title: '1'),
        );
        final Future<void> close = u.repository.close();
        await put;
        await close;
        await _settle();
        expect(events, const <StorageEvent>[StorageEvent.put('a')]);
      });
    });
  });
}

/// Subscribes to [repository] and returns the live list of events.
List<StorageEvent> _collect(RecordRepository<TestNote> repository) {
  final List<StorageEvent> events = <StorageEvent>[];
  final StreamSubscription<StorageEvent> sub = repository.watch().listen(
    events.add,
  );
  addTearDown(sub.cancel);
  return events;
}

/// Lets queued stream deliveries run.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
