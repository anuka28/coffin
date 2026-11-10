import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/envelope.dart';
import 'package:coffin_core/src/storage/envelope_repository.dart';
import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:coffin_core/src/storage/migration_hook.dart';
import 'package:coffin_core/src/storage/record_codec.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/storage_generators.dart';
import 'support/test_note.dart';

// Pure: memory store only, no dart:io, no hive_ce. Runs on the VM and in
// Chrome. Properties 5, 7, 8 and 9 of crypt-storage live in this file, each in
// its own group.

const int _numRuns = 200;

// ---------------------------------------------------------------------------
// Reusable helpers
// ---------------------------------------------------------------------------

/// Everything in [store]: every key with its raw string, keys sorted.
Future<Map<String, String?>> snapshotRawStore(MemoryRawStore store) async {
  final List<String> keys = await store.keys()
    ..sort((String a, String b) => a.compareTo(b));
  return <String, String?>{for (final String k in keys) k: await store.read(k)};
}

/// Waits long enough for broadcast stream listeners to receive queued events.
Future<void> settleEvents() => Future<void>.delayed(Duration.zero);

/// A [TestNoteCodec] whose `encode` can inject one unsafe value.
final class UnsafeNoteCodec implements RecordCodec<TestNote> {
  /// Creates a codec that adds [unsafe] to every encoded map.
  const UnsafeNoteCodec(this.unsafe);

  /// The unsafe value placed under the `bad` property.
  final Object? unsafe;

  @override
  JsonMap encode(TestNote record) => <String, Object?>{
    ...const TestNoteCodec().encode(record),
    'bad': unsafe,
  };

  @override
  TestNote decode(JsonMap json) => const TestNoteCodec().decode(json);
}

/// The kinds of unsafe value, in the order [unsafeValueFor] builds them.
const List<String> unsafeKindNames = <String>[
  'NaN',
  'infinity',
  '-infinity',
  'int 2^53',
  'int -2^53',
  'non-String map key',
  'DateTime',
  'NaN in a list',
];

/// Builds the unsafe value for [kind] (an index into [unsafeKindNames]).
Object? unsafeValueFor(int kind) {
  switch (kind) {
    case 0:
      return double.nan;
    case 1:
      return double.infinity;
    case 2:
      return double.negativeInfinity;
    case 3:
      return 9007199254740992;
    case 4:
      return -9007199254740992;
    case 5:
      return <Object?, Object?>{1: 'x'};
    case 6:
      return DateTime.utc(2020);
    default:
      return <Object?>[1, double.nan];
  }
}

/// Generates an index into [unsafeKindNames].
Generator<int> get anyUnsafeKind => anyIntBetween(0, unsafeKindNames.length);

// ---------------------------------------------------------------------------
// Property 5
// ---------------------------------------------------------------------------

int _property5Runs = 0;
int _property7Runs = 0;
int _property8Runs = 0;
int _property9Runs = 0;

void main() {
  group('Property 5: a rejected put changes nothing', () {
    // Feature: crypt-storage, Property 5: a rejected put changes nothing
    // Validates: Requirements 6.6, 14.6
    Glados3(
      anyListBetween(0, 5, anyTestNote),
      anyUnsafeKind,
      anyValidKey,
      ExploreConfig(numRuns: _numRuns),
    ).test('unsafe encode result is rejected without any change', (
      seeds,
      kind,
      badKey,
    ) async {
      _property5Runs++;
      final String why =
          'seeds=$seeds unsafe=${unsafeKindNames[kind]} badKey='
          '${describeKey(badKey)}';
      final MemoryRawStore store = MemoryRawStore();
      // The seeding repository is valid; the bad one shares the same store.
      final EnvelopeRepository<TestNote> good = EnvelopeRepository<TestNote>(
        store: store,
        codec: const TestNoteCodec(),
        currentVersion: 1,
      );
      final EnvelopeRepository<TestNote> bad = EnvelopeRepository<TestNote>(
        store: store,
        codec: UnsafeNoteCodec(unsafeValueFor(kind)),
        currentVersion: 1,
      );
      final List<StorageEvent> events = <StorageEvent>[];
      StreamSubscription<StorageEvent>? sub;
      try {
        for (int i = 0; i < seeds.length; i++) {
          await good.put(ordinaryKeys[i], seeds[i]);
        }
        final List<TestNote> recordsBefore = await good.getAll();
        final Map<String, String?> rawBefore = await snapshotRawStore(store);
        expect(recordsBefore, hasLength(seeds.length), reason: why);

        sub = bad.watch().listen(events.add);
        await settleEvents();

        Object? error;
        try {
          await bad.put(badKey, const TestNote(title: 'rejected'));
        } catch (e) {
          error = e;
        }
        expect(error, isA<ArgumentError>(), reason: why);

        expect(await good.getAll(), recordsBefore, reason: why);
        expect(await snapshotRawStore(store), rawBefore, reason: why);

        // Sentinel: if the bad put had emitted, its event would come first.
        await bad.clear();
        await settleEvents();
        expect(events, <StorageEvent>[const StorageEvent.clear()], reason: why);
      } finally {
        await sub?.cancel();
        await good.close();
        await bad.close();
      }
    });

    test('property 5 body ran $_numRuns times', () {
      expect(_property5Runs, _numRuns);
    });
  });

  group('Property 7: stored entries are decoded by the table', () {
    // Feature: crypt-storage, Property 7: stored entries are decoded by the table
    // Validates: Requirements 2.6, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 10.1, 10.2, 10.3, 10.10
    Glados2(
      anyStoredEntrySet,
      anyIntBetween(0, 3),
      ExploreConfig(numRuns: _numRuns),
    ).test('each entry reads as the decode table says, and only that', (
      set,
      mode,
    ) async {
      _property7Runs++;
      // mode 0: no hook. 1: identity hook. 2: throwing hook.
      final bool hasHook = mode != 0;
      final bool hookThrows = mode == 2;
      final String mix = 'currentVersion=${set.currentVersion} mode=$mode';

      final List<int> hookVersions = <int>[];
      final List<JsonMap> hookArgs = <JsonMap>[];
      final List<String> hookSnapshots = <String>[];
      final List<StorageIssue> issues = <StorageIssue>[];

      MigrationHook? hook;
      if (hasHook) {
        hook = (int from, JsonMap data) {
          hookVersions.add(from);
          hookArgs.add(data);
          hookSnapshots.add(jsonEncode(data));
          if (hookThrows) throw StateError('hook failed');
          return data;
        };
      }

      final MemoryRawStore store = MemoryRawStore(set.raw);
      final EnvelopeRepository<TestNote> repo = EnvelopeRepository<TestNote>(
        store: store,
        codec: const TestNoteCodec(),
        currentVersion: set.currentVersion,
        migrate: hook,
        reportIssue: issues.add,
      );
      try {
        final Map<String, String?> rawBefore = await snapshotRawStore(store);
        final List<StoredEntry> sorted = List<StoredEntry>.of(set.entries)
          ..sort((StoredEntry a, StoredEntry b) => a.key.compareTo(b.key));

        String why(StoredEntry e) =>
            '${e.entryClass.name} key=${describeKey(e.key)} '
            'version=${e.version} $mix';

        // Expected records and issues, in key order.
        final List<TestNote> expectedRecords = <TestNote>[];
        final List<StoredEntry> skipped = <StoredEntry>[];
        final List<StoredEntry> migrated = <StoredEntry>[];
        for (final StoredEntry e in sorted) {
          final TestNote? note = e.expectedNote(
            hasHook: hasHook,
            hookThrows: hookThrows,
          );
          if (note != null) expectedRecords.add(note);
          if (e.expectedIssue(hasHook: hasHook, hookThrows: hookThrows) !=
              null) {
            skipped.add(e);
          }
          if (hasHook && e.entryClass == StoredEntryClass.lowerValid) {
            migrated.add(e);
          }
        }
        final String all = 'entries=${sorted.map(why).toList()}';

        void expectNoMarker(StoredEntry e) {
          for (final StoredEntry other in sorted) {
            for (final StorageIssue issue in issues) {
              expect(
                issue.message.contains(other.marker),
                isFalse,
                reason: 'message "${issue.message}" leaks marker of ${why(e)}',
              );
            }
          }
        }

        // One getAll: records, issues, hook calls.
        final List<TestNote> records = await repo.getAll();
        expect(records, expectedRecords, reason: 'getAll: $all');
        expect(
          issues.map((StorageIssue i) => (i.kind, i.key)).toList(),
          <(StorageIssueKind, String)>[
            for (final StoredEntry e in skipped)
              (
                e.expectedIssue(hasHook: hasHook, hookThrows: hookThrows)!,
                e.key,
              ),
          ],
          reason: 'getAll issues, one per skipped entry: $all',
        );
        expect(hookVersions, <int>[
          for (final StoredEntry e in migrated) e.version!,
        ], reason: 'getAll hook calls, once per lower entry: $all');
        for (int i = 0; i < migrated.length; i++) {
          final StoredEntry e = migrated[i];
          final Object? stored =
              (jsonDecode(e.raw) as Map<String, Object?>)['data'];
          expect(
            hookSnapshots[i],
            jsonEncode(stored),
            reason: 'hook payload equals stored data: ${why(e)}',
          );
        }
        for (final StoredEntry e in sorted) {
          expectNoMarker(e);
        }

        // Then one get per entry: one more issue / hook call each.
        final List<JsonMap> firstArgs = List<JsonMap>.of(hookArgs);
        for (final StoredEntry e in sorted) {
          issues.clear();
          hookVersions.clear();
          final TestNote? got = await repo.get(e.key);
          final StorageIssueKind? kind = e.expectedIssue(
            hasHook: hasHook,
            hookThrows: hookThrows,
          );
          expect(
            got,
            e.expectedNote(hasHook: hasHook, hookThrows: hookThrows),
            reason: 'get: ${why(e)}',
          );
          expect(
            issues.map((StorageIssue i) => (i.kind, i.key)).toList(),
            <(StorageIssueKind, String)>[if (kind != null) (kind, e.key)],
            reason: 'get issues: ${why(e)}',
          );
          expect(hookVersions, <int>[
            if (hasHook && e.entryClass == StoredEntryClass.lowerValid)
              e.version!,
          ], reason: 'get hook calls: ${why(e)}');
          expectNoMarker(e);
        }

        // Every hook call received its own copy of the payload.
        for (int i = 0; i < hookArgs.length; i++) {
          for (int j = i + 1; j < hookArgs.length; j++) {
            expect(
              identical(hookArgs[i], hookArgs[j]),
              isFalse,
              reason: 'hook payloads are distinct copies: $all',
            );
          }
        }
        expect(firstArgs.length, migrated.length, reason: all);

        // Reads never write.
        expect(
          await snapshotRawStore(store),
          rawBefore,
          reason: 'reads leave the store untouched: $all',
        );
      } finally {
        await repo.close();
      }
    });

    test('property 7 body ran $_numRuns times', () {
      expect(_property7Runs, _numRuns);
    });
  });

  group('Property 8: reads change nothing', () {
    // Feature: crypt-storage, Property 8: reads change nothing
    // Validates: Requirements 9.6, 9.9, 10.5
    Glados3(
      anyStoredEntrySet,
      anyListBetween(0, 13, anyIntBetween(0, 64)),
      anyIntBetween(0, 3),
      ExploreConfig(numRuns: _numRuns),
    ).test('get and getAll leave every raw key and string untouched', (
      set,
      codes,
      mode,
    ) async {
      _property8Runs++;
      final MemoryRawStore store = MemoryRawStore(set.raw);

      // Two repositories share one store: one without a hook and one whose
      // hook mutates its argument and returns it (the stress case).
      final EnvelopeRepository<TestNote> plain = EnvelopeRepository<TestNote>(
        store: store,
        codec: const TestNoteCodec(),
        currentVersion: set.currentVersion,
      );
      final EnvelopeRepository<TestNote> hooked = EnvelopeRepository<TestNote>(
        store: store,
        codec: const TestNoteCodec(),
        currentVersion: set.currentVersion,
        migrate: (int from, JsonMap data) {
          data['title'] = 'mutated from $from';
          data['count'] = -1;
          data['extra'] = <String, Object?>{'touched': true};
          data.remove('tags');
          return data;
        },
      );

      final List<String> seeded = <String>[
        for (final StoredEntry e in set.entries) e.key,
      ];
      final List<String> absent = <String>[
        for (final String k in ordinaryKeys)
          if (!seeded.contains(k)) k,
      ];
      final List<String> readKeys = <String>[
        ...seeded,
        ...absent,
        if (seeded.isEmpty && absent.isEmpty) 'a',
      ];

      // Decode each code into a read: kind (getAll, get seeded, get absent,
      // get any), repository (plain or hooked) and key.
      final List<String> names = <String>[];
      final List<Future<Object?> Function()> reads =
          <Future<Object?> Function()>[];
      for (final int code in codes) {
        final EnvelopeRepository<TestNote> repo = (code ~/ 4) % 2 == 0
            ? plain
            : hooked;
        final String repoName = identical(repo, plain) ? 'plain' : 'hooked';
        final int pick = code ~/ 8;
        switch (code % 4) {
          case 0:
            names.add('$repoName.getAll()');
            reads.add(repo.getAll);
          case 1:
            final String key = seeded.isEmpty
                ? readKeys[pick % readKeys.length]
                : seeded[pick % seeded.length];
            names.add('$repoName.get(${describeKey(key)})');
            reads.add(() => repo.get(key));
          case 2:
            final String key = absent.isEmpty
                ? readKeys[pick % readKeys.length]
                : absent[pick % absent.length];
            names.add('$repoName.get(${describeKey(key)})');
            reads.add(() => repo.get(key));
          default:
            final String key = readKeys[pick % readKeys.length];
            names.add('$repoName.get(${describeKey(key)})');
            reads.add(() => repo.get(key));
        }
      }

      final String why =
          'currentVersion=${set.currentVersion} '
          'classes=${[for (final StoredEntry e in set.entries) '${e.entryClass.name}@${describeKey(e.key)}']} '
          'sequence=$names concurrency=${const <String>['awaited one by one', 'all fired then awaited together', 'fired in groups of three'][mode]}';

      try {
        final Map<String, String?> before = await snapshotRawStore(store);
        expect(before, <String, String?>{
          for (final MapEntry<String, String> e in set.raw.entries)
            e.key: e.value,
        }, reason: 'seeding is faithful: $why');

        switch (mode) {
          case 0:
            for (final Future<Object?> Function() read in reads) {
              await read();
            }
          case 1:
            await Future.wait(<Future<Object?>>[
              for (final Future<Object?> Function() read in reads) read(),
            ]);
          default:
            for (int i = 0; i < reads.length; i += 3) {
              final int end = i + 3 > reads.length ? reads.length : i + 3;
              await Future.wait(<Future<Object?>>[
                for (int j = i; j < end; j++) reads[j](),
              ]);
            }
        }

        expect(
          await snapshotRawStore(store),
          before,
          reason: 'raw store identical after reads: $why',
        );
      } finally {
        await plain.close();
        await hooked.close();
      }
    });

    test('property 8 body ran $_numRuns times', () {
      expect(_property8Runs, _numRuns);
    });
  });

  group('Property 9: put stores the current version', () {
    // Feature: crypt-storage, Property 9: put stores the current version
    // Validates: Requirements 9.1, 9.10, 10.6
    Glados(
      any.combine5<
        TestNote,
        int,
        int,
        String,
        int,
        ({TestNote record, int version, int classCode, String key, int seed})
      >(
        anyTestNote,
        anyEnvelopeVersion,
        anyIntBetween(0, StoredEntryClass.values.length + 1),
        anyValidKey,
        anyIntBetween(0, 1 << 30),
        (record, version, classCode, key, seed) => (
          record: record,
          version: version,
          classCode: classCode,
          key: key,
          seed: seed,
        ),
      ),
      ExploreConfig(numRuns: _numRuns),
    ).test('put writes the current version and get reads it back', (
      args,
    ) async {
      final TestNote record = args.record;
      final int currentVersion = args.version;
      final int classCode = args.classCode;
      final String key = args.key;
      final int seed = args.seed;
      _property9Runs++;
      // classCode 0 is "absent"; the others are the entry classes.
      final bool absent = classCode == 0;
      final StoredEntryClass? wanted = absent
          ? null
          : StoredEntryClass.values[classCode - 1];
      final bool withHook = seed.isEven;
      final math.Random random = math.Random(seed);

      final StoredEntry? seeded = wanted == null
          ? null
          : buildStoredEntry(
              random: random,
              entryClass: wanted,
              currentVersion: currentVersion,
              key: key,
              marker: 'MK$seed',
            );
      final String why =
          'entry=${seeded?.entryClass.name ?? 'absent'} key=${describeKey(key)} '
          'currentVersion=$currentVersion hook=$withHook record=$record';

      final MemoryRawStore store = MemoryRawStore(<String, String>{
        if (seeded != null) key: seeded.raw,
      });
      final EnvelopeRepository<TestNote> repo = EnvelopeRepository<TestNote>(
        store: store,
        codec: const TestNoteCodec(),
        currentVersion: currentVersion,
        migrate: withHook ? (int from, JsonMap data) => data : null,
      );
      final List<StorageEvent> events = <StorageEvent>[];
      StreamSubscription<StorageEvent>? sub;
      try {
        sub = repo.watch().listen(events.add);
        await settleEvents();

        // Read the old entry first; whatever it gave, the put overwrites it.
        await repo.get(key);
        await settleEvents();
        expect(events, isEmpty, reason: 'a read emits nothing: $why');

        await repo.put(key, record);
        await settleEvents();

        final String? raw = await store.read(key);
        expect(raw, isNotNull, reason: 'raw entry exists after put: $why');
        final Envelope envelope = EnvelopeCodec.parse(raw!);
        expect(
          envelope.version,
          currentVersion,
          reason: 'raw envelope has the current version: $why',
        );
        expect(
          deepEquals(envelope.data, const TestNoteCodec().encode(record)),
          isTrue,
          reason:
              'raw data equals the encoded record: $why data='
              '${envelope.data}',
        );
        expect(
          await repo.get(key),
          record,
          reason: 'get returns an equal record: $why',
        );
        expect(events, <StorageEvent>[
          StorageEvent.put(key),
        ], reason: 'exactly one put event for the key: $why');
      } finally {
        await sub?.cancel();
        await repo.close();
      }
    });

    test('property 9 body ran $_numRuns times', () {
      expect(_property9Runs, _numRuns);
    });
  });
}
