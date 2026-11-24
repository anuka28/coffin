import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/new_grave_ids.dart';

void main() {
  group('NewGraveIds.diff', () {
    test('equal lists give an empty diff (loaded graves are never new)', () {
      final ids = ['a', 'b', 'c'];
      expect(NewGraveIds.diff(previous: ids, next: ids), isEmpty);
      expect(NewGraveIds.diff(previous: ['a', 'b'], next: ['a', 'b']), isEmpty);
    });

    test('empty previous returns every next id in order', () {
      expect(NewGraveIds.diff(previous: const [], next: ['c', 'a', 'b']), [
        'c',
        'a',
        'b',
      ]);
    });

    test('mixed before and after returns only the new ids in next order', () {
      expect(
        NewGraveIds.diff(
          previous: ['a', 'b', 'c'],
          next: ['z', 'a', 'y', 'b', 'c'],
        ),
        ['z', 'y'],
      );
    });

    test('a removed id gives an empty diff', () {
      expect(
        NewGraveIds.diff(previous: ['a', 'b', 'c'], next: ['a', 'c']),
        isEmpty,
      );
    });

    test('a reordered list with no new id gives an empty diff', () {
      expect(
        NewGraveIds.diff(previous: ['a', 'b', 'c'], next: ['c', 'a', 'b']),
        isEmpty,
      );
    });
  });
}
