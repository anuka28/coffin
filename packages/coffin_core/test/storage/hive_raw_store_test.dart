@TestOn('vm')
library;

import 'dart:io';

import 'package:coffin_core/src/storage/hive_raw_store.dart';
import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:coffin_core/src/storage/raw_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/hive_test_box.dart';

void main() {
  late HiveTestBox hive;
  late HiveRawStore store;

  setUp(() async {
    hive = await openHiveTestBox();
    addTearDown(hive.dispose);
    store = HiveRawStore(hive.box);
  });

  test('read returns null for an absent key', () async {
    expect(await store.read('missing'), isNull);
  });

  test(
    'write then read returns the value, and overwrite replaces it',
    () async {
      await store.write('a', 'one');
      expect(await store.read('a'), 'one');
      await store.write('a', 'two');
      expect(await store.read('a'), 'two');
    },
  );

  test('remove reports whether the key existed', () async {
    await store.write('a', '1');
    expect(await store.remove('a'), isTrue);
    expect(await store.read('a'), isNull);
    expect(await store.remove('a'), isFalse);
  });

  test('keys lists every key, removeAll empties the store', () async {
    await store.write('a', '1');
    await store.write('b', '2');
    expect((await store.keys())..sort(), ['a', 'b']);
    await store.removeAll();
    expect(await store.keys(), isEmpty);
    expect(await store.read('a'), isNull);
  });

  test('a foreign non-String value reads as an empty string', () async {
    await hive.box.put('k', 42);
    expect(await store.read('k'), '');
    expect(await store.keys(), ['k']);
  });

  test('non-String keys are not reported', () async {
    await hive.box.put(1, 'x');
    await store.write('s', 'y');
    expect(await store.keys(), ['s']);
  });

  test('close keeps the data on disk', () async {
    await store.write('a', 'kept');
    await store.close();
    expect(hive.box.isOpen, isFalse);

    final reopened = await HiveRawStore.open(hive.name, hive.directory.path);
    // Registered after hive.dispose, so it runs before it.
    addTearDown(reopened.close);
    expect(await reopened.read('a'), 'kept');
  });

  test('open uses the given location', () async {
    final dir = await Directory.systemTemp.createTemp('crypt_storage_');
    final name = 'crypt_t_open_${DateTime.now().microsecondsSinceEpoch}';
    HiveRawStore? opened;
    try {
      opened = await HiveRawStore.open(name, dir.path);
      await opened.write('a', '1');
      expect(await opened.read('a'), '1');
      expect(
        dir.listSync().any((e) => e.path.contains(name)),
        isTrue,
        reason: 'box files should be written into the given directory',
      );
    } finally {
      await opened?.close();
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });

  test('matches MemoryRawStore for the same operations', () async {
    final memory = MemoryRawStore();
    final stores = <RawStore>[memory, store];
    Future<void> both(Future<Object?> Function(RawStore s) op) async {
      for (final s in stores) {
        await op(s);
      }
    }

    await both((s) => s.write('a', '1'));
    await both((s) => s.write('b', '2'));
    await both((s) => s.write('a', '3'));
    await both((s) => s.remove('b'));
    await both((s) => s.remove('zzz'));
    await both((s) => s.write('c', ''));

    for (final key in ['a', 'b', 'c', 'zzz']) {
      expect(await store.read(key), await memory.read(key), reason: key);
    }
    expect((await store.keys()).toSet(), (await memory.keys()).toSet());

    await both((s) => s.removeAll());
    expect(await store.keys(), await memory.keys());
  });
}
