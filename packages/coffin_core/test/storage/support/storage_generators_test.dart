import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/key_validator.dart';
import 'package:coffin_core/src/storage/record_repository.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'repository_contract.dart';
import 'storage_generators.dart';
import 'test_note.dart';

const int _numRuns = 200;

T _sample<T>(Generator<T> generator, math.Random random) =>
    generator(random, 30).value;

/// A tiny map-backed repository, only here to prove that the shared contract
/// compiles and passes against a correct implementation.
final class _FakeRepository implements RecordRepository<TestNote> {
  final Map<String, String> raw = <String, String>{};
  final StreamController<StorageEvent> _events =
      StreamController<StorageEvent>.broadcast();
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  Future<void>? _closing;

  Future<R> _run<R>(R Function() body) {
    final Future<R> result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _checkOpen() {
    if (_closed) throw StateError('closed');
  }

  @override
  Future<TestNote?> get(String key) async {
    _checkOpen();
    KeyValidator.check(key);
    return _run(() {
      final String? text = raw[key];
      return text == null
          ? null
          : const TestNoteCodec().decode(
              (jsonDecode(text) as Map<String, Object?>)['data']! as JsonMap,
            );
    });
  }

  @override
  Future<List<TestNote>> getAll() async {
    _checkOpen();
    return _run(() {
      final List<String> keys = raw.keys.toList()..sort();
      return <TestNote>[
        for (final String k in keys)
          const TestNoteCodec().decode(
            (jsonDecode(raw[k]!) as Map<String, Object?>)['data']! as JsonMap,
          ),
      ];
    });
  }

  @override
  Future<void> put(String key, TestNote record) async {
    _checkOpen();
    KeyValidator.check(key);
    final String text = jsonEncode(<String, Object?>{
      'v': 1,
      'data': const TestNoteCodec().encode(record),
    });
    return _run(() {
      raw[key] = text;
      _events.add(StorageEvent.put(key));
    });
  }

  @override
  Future<void> delete(String key) async {
    _checkOpen();
    KeyValidator.check(key);
    return _run(() {
      if (raw.remove(key) != null) _events.add(StorageEvent.delete(key));
    });
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    return _run(() {
      raw.clear();
      _events.add(const StorageEvent.clear());
    });
  }

  @override
  Stream<StorageEvent> watch() =>
      _closed ? const Stream<StorageEvent>.empty() : _events.stream;

  @override
  Future<void> close() {
    _closed = true;
    return _closing ??= _run(() => _events.close());
  }
}

void main() {
  group('TestNote', () {
    test('has value equality, including nested collections', () {
      const TestNote a = TestNote(
        title: 't',
        count: 1,
        weight: 2.0,
        tags: <String>['x'],
        extra: <String, Object?>{
          'k': <Object?>[1, null],
        },
      );
      final TestNote b = TestNote(
        title: 't',
        count: 1,
        weight: 2,
        tags: <String>['x'],
        extra: <String, Object?>{
          'k': <Object?>[1.0, null],
        },
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const TestNote(title: 't', count: 2)));
      expect(
        const TestNote(title: 't', weight: 0.0).hashCode,
        const TestNote(title: 't', weight: -0.0).hashCode,
      );
    });

    test('prints a readable summary', () {
      expect(
        const TestNote(title: 'x', count: 2).toString(),
        'TestNote(title: x, count: 2)',
      );
      expect(
        const TestNote(title: 'x', weight: 1.5, tags: <String>['a']).toString(),
        'TestNote(title: x, count: 0, weight: 1.5, tags: [a])',
      );
    });

    test('codec decode turns an int weight back into a double', () {
      final TestNote note = const TestNoteCodec().decode(<String, Object?>{
        'title': 't',
        'count': 1,
        'weight': 3, // what an integral double looks like after JSON
        'tags': <Object?>[],
        'extra': <String, Object?>{},
      });
      expect(note.weight, 3.0);
      expect(note.weight, isA<double>());
    });

    test('codec decode throws on a wrong type', () {
      expect(
        () => const TestNoteCodec().decode(<String, Object?>{
          'title': 5,
          'count': 1,
          'weight': null,
          'tags': <Object?>[],
          'extra': <String, Object?>{},
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('generators (sampled)', () {
    test('keys: ordinary keys dominate, every boundary key shows up', () {
      final math.Random random = math.Random(7);
      final List<String> keys = <String>[
        for (int i = 0; i < 2000; i++) _sample(anyKey, random),
      ];
      final int ordinary = keys.where(ordinaryKeys.contains).length;
      expect(ordinary / keys.length, greaterThan(0.7));
      for (final String boundary in BoundaryKeys.all) {
        expect(keys, contains(boundary), reason: describeKey(boundary));
      }
    });

    test('valid keys are always accepted by the validator', () {
      final math.Random random = math.Random(8);
      for (int i = 0; i < 500; i++) {
        expect(KeyValidator.isValid(_sample(anyValidKey, random)), isTrue);
      }
    });

    test('boundary key verdicts match the design table', () {
      expect(BoundaryKeys.valid.every(KeyValidator.isValid), isTrue);
      expect(BoundaryKeys.invalid.any(KeyValidator.isValid), isFalse);
      expect(BoundaryKeys.all, hasLength(11));
      expect(BoundaryKeys.b3.length, 255);
      expect(BoundaryKeys.b4.length, 256);
      expect(BoundaryKeys.b10.length, 128);
    });

    test('stored entries: every class appears and carries its marker', () {
      final math.Random random = math.Random(9);
      final Set<StoredEntryClass> seen = <StoredEntryClass>{};
      for (int i = 0; i < 300; i++) {
        final StoredEntrySet set = _sample(anyStoredEntrySet, random);
        expect(
          set.entries.map((StoredEntry e) => e.key).toSet().length,
          set.entries.length,
        );
        for (final StoredEntry e in set.entries) {
          seen.add(e.entryClass);
          expect(KeyValidator.isValid(e.key), isTrue);
          // Bare scalars such as `42` or `null` cannot carry a marker.
          if (e.entryClass != StoredEntryClass.jsonNonObject) {
            expect(e.raw, contains(e.marker));
          }
          expect(
            e.expectedIssue(hasHook: true) == null,
            e.note != null && e.entryClass != StoredEntryClass.higherVersion,
          );
        }
      }
      expect(seen, StoredEntryClass.values.toSet());
    });

    test('stored entry classes parse the way the table says', () {
      final math.Random random = math.Random(10);
      for (final StoredEntryClass kind in StoredEntryClass.values) {
        final StoredEntry e = buildStoredEntry(
          random: random,
          entryClass: kind,
          currentVersion: 3,
          key: 'a',
          marker: 'MARK',
        );
        Object? decoded;
        try {
          decoded = jsonDecode(e.raw);
        } on FormatException {
          decoded = const FormatException();
        }
        switch (kind) {
          case StoredEntryClass.garbageText:
            expect(decoded, isA<FormatException>());
          case StoredEntryClass.jsonNonObject:
            expect(decoded, isNot(isA<Map<Object?, Object?>>()));
          case StoredEntryClass.missingVersion:
            expect(
              (decoded! as Map<Object?, Object?>).containsKey('v'),
              isFalse,
            );
          case StoredEntryClass.currentValid:
            expect((decoded! as Map<Object?, Object?>)['v'], 3);
          case StoredEntryClass.lowerValid:
            expect(
              (decoded! as Map<Object?, Object?>)['v'] as int,
              lessThan(3),
            );
          case StoredEntryClass.higherVersion:
            expect(
              (decoded! as Map<Object?, Object?>)['v'] as int,
              greaterThan(3),
            );
          case StoredEntryClass.invalidVersion:
          case StoredEntryClass.dataNotObject:
          case StoredEntryClass.codecThrows:
            expect(decoded, isA<Map<Object?, Object?>>());
        }
      }
    });

    test('ops print readably', () {
      expect(
        const PutOp('a', TestNote(title: 'x', count: 2)).toString(),
        'put("a", TestNote(title: x, count: 2))',
      );
      expect(const DeleteOp('b').toString(), 'delete("b")');
      expect(const ClearOp().toString(), 'clear()');
      expect(const DeleteOp('').toString(), 'delete("")');
      expect(DeleteOp(BoundaryKeys.b9).toString(), r'delete("\ud800")');
      expect(DeleteOp(BoundaryKeys.b3).toString(), contains('255 units'));
    });

    test('op sequences respect the length limit and mix op kinds', () {
      final math.Random random = math.Random(11);
      final Set<Type> kinds = <Type>{};
      for (int i = 0; i < 100; i++) {
        final List<Op> ops = _sample(anyOps(), random);
        expect(ops.length, lessThanOrEqualTo(30));
        kinds.addAll(ops.map((Op op) => op.runtimeType));
      }
      expect(kinds, <Type>{PutOp, DeleteOp, ClearOp});
    });
  });

  group('generators (properties)', () {
    // Feature: crypt-storage, support for Properties 1 and 2
    // Validates: Requirements 12.1, 12.10
    Glados(anyTestNote, ExploreConfig(numRuns: _numRuns)).test(
      'a TestNote survives codec and JSON text exactly',
      (TestNote note) {
        const TestNoteCodec codec = TestNoteCodec();
        final JsonMap encoded = codec.encode(note);
        final Object? viaJson = jsonDecode(jsonEncode(encoded));
        expect(codec.decode(viaJson! as JsonMap), note);
      },
    );

    Glados(anySafeMap, ExploreConfig(numRuns: _numRuns)).test(
      'a safe map survives JSON text and deepEquals agrees',
      (JsonMap map) {
        expect(deepEquals(jsonDecode(jsonEncode(map)), map), isTrue);
      },
    );
  });

  // The fake only proves the contract is usable; real repositories call it too.
  defineRepositoryContract('in-test fake', () async {
    final _FakeRepository repo = _FakeRepository();
    return RepoUnderTest(
      repository: repo,
      readRaw: () async => Map<String, String>.of(repo.raw),
      issues: <StorageIssue>[],
      dispose: () async {},
    );
  });
}
