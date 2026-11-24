import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/stable_hash.dart';

void main() {
  group('StableHash.of', () {
    test('empty string gives the start value 7', () {
      expect(StableHash.of(''), 7);
    });

    test('g1 gives a fixed integer', () {
      expect(StableHash.of('g1'), 9969);
    });

    test('a 200-character string gives a fixed integer', () {
      expect(StableHash.of('a' * 200), 24571271);
    });

    test('a non-ASCII string gives a fixed integer', () {
      expect(StableHash.of('h\u00e9llo \u2620\u{1F47B}'), 100814981);
    });

    test('a string with a lone surrogate gives a fixed integer', () {
      expect(StableHash.of('a\uD800b'), 2016028);
    });

    test('result is below 2^31 and not negative', () {
      for (final s in ['', 'g1', 'a' * 200, 'z' * 5000, '\uFFFF' * 1000]) {
        final h = StableHash.of(s);
        expect(h, greaterThanOrEqualTo(0));
        expect(h, lessThan(2147483648));
      }
    });

    test('same input gives same output', () {
      expect(StableHash.of('grave-42'), StableHash.of('grave-42'));
    });
  });
}
