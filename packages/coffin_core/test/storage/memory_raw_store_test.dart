import 'package:coffin_core/src/storage/memory_raw_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryRawStore', () {
    test('read returns seeded value and null when absent', () async {
      final store = MemoryRawStore({'a': '1'});
      expect(await store.read('a'), '1');
      expect(await store.read('b'), isNull);
    });

    test('keys lists every stored key', () async {
      final store = MemoryRawStore({'a': '1', 'b': '2'});
      expect(await store.keys(), unorderedEquals(['a', 'b']));
      expect(await MemoryRawStore().keys(), isEmpty);
    });

    test('write stores and overwrites', () async {
      final store = MemoryRawStore();
      await store.write('a', '1');
      await store.write('a', '2');
      expect(await store.read('a'), '2');
      expect(await store.keys(), ['a']);
    });

    test('remove reports whether the key existed', () async {
      final store = MemoryRawStore({'a': ''});
      expect(await store.remove('a'), isTrue);
      expect(await store.remove('a'), isFalse);
      expect(await store.read('a'), isNull);
    });

    test('removeAll empties the store', () async {
      final store = MemoryRawStore({'a': '1', 'b': '2'});
      await store.removeAll();
      expect(await store.keys(), isEmpty);
    });

    test('close drops the entries', () async {
      final store = MemoryRawStore({'a': '1'});
      await store.close();
      expect(await store.keys(), isEmpty);
      expect(await store.read('a'), isNull);
    });

    test('two instances share nothing', () async {
      final seed = {'a': '1'};
      final one = MemoryRawStore(seed);
      final two = MemoryRawStore(seed);
      await one.write('b', '2');
      seed['c'] = '3';
      await one.remove('a');
      expect(await two.keys(), ['a']);
      expect(await one.keys(), ['b']);
    });

    test('a bad seed key throws ArgumentError', () {
      expect(() => MemoryRawStore({'': 'x'}), throwsArgumentError);
      expect(() => MemoryRawStore({'é': 'x'}), throwsArgumentError);
      expect(() => MemoryRawStore({'a' * 256: 'x'}), throwsArgumentError);
    });
  });
}
