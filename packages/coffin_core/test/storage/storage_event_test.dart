import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:coffin_core/src/storage/storage_event_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageEvent', () {
    test('named constructors set kind and key', () {
      expect(const StorageEvent.put('a').kind, StorageEventKind.put);
      expect(const StorageEvent.put('a').key, 'a');
      expect(const StorageEvent.delete('b').kind, StorageEventKind.delete);
      expect(const StorageEvent.delete('b').key, 'b');
    });

    test('clear has a null key', () {
      const event = StorageEvent.clear();
      expect(event.kind, StorageEventKind.clear);
      expect(event.key, isNull);
    });

    test('equal events share == and hashCode', () {
      expect(const StorageEvent.put('a'), const StorageEvent.put('a'));
      expect(
        const StorageEvent.put('a').hashCode,
        const StorageEvent.put('a').hashCode,
      );
      expect(const StorageEvent.clear(), const StorageEvent.clear());
      expect(
        const StorageEvent.clear().hashCode,
        const StorageEvent.clear().hashCode,
      );
    });

    test('differs when kind differs', () {
      expect(
        const StorageEvent.put('a'),
        isNot(const StorageEvent.delete('a')),
      );
      expect(
        const StorageEvent.put('a').hashCode,
        isNot(const StorageEvent.delete('a').hashCode),
      );
    });

    test('differs when key differs', () {
      expect(const StorageEvent.put('a'), isNot(const StorageEvent.put('b')));
      expect(
        const StorageEvent.put('a').hashCode,
        isNot(const StorageEvent.put('b').hashCode),
      );
      expect(
        const StorageEvent(StorageEventKind.clear, 'a'),
        isNot(const StorageEvent.clear()),
      );
    });

    test('is not equal to other types', () {
      expect(const StorageEvent.put('a') == Object(), isFalse);
    });

    test('toString is readable', () {
      expect(const StorageEvent.put('a').toString(), 'StorageEvent.put("a")');
      expect(
        const StorageEvent.delete('b').toString(),
        'StorageEvent.delete("b")',
      );
      expect(const StorageEvent.clear().toString(), 'StorageEvent.clear()');
    });
  });
}
