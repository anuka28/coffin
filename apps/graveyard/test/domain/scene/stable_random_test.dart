import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/stable_random.dart';

List<int> _take(int seed, int max, int count) {
  final r = StableRandom(seed);
  return [for (var i = 0; i < count; i++) r.nextInt(max)];
}

void main() {
  group('StableRandom', () {
    test('seed 1 gives a fixed sequence', () {
      expect(_take(1, 1000, 5), [542, 588, 125, 627, 435]);
    });

    test('seed 0 gives a fixed sequence', () {
      expect(_take(0, 1000, 5), [271, 794, 886, 637, 41]);
    });

    test('negative seeds give fixed sequences', () {
      expect(_take(-1, 1000, 5), [376, 853, 761, 10, 606]);
      expect(_take(-5, 1000, 5), [292, 677, 158, 50, 30]);
    });

    test('a small max gives a fixed sequence', () {
      expect(_take(42, 10, 5), [3, 1, 3, 5, 6]);
    });

    test('same seed gives the same sequence', () {
      expect(_take(7, 100, 20), _take(7, 100, 20));
    });

    test('every value stays in [0, max)', () {
      for (final seed in [0, 1, -1, 123456, 2147483646, -2147483647]) {
        for (final max in [1, 2, 7, 1000, 2147483647]) {
          final r = StableRandom(seed);
          for (var i = 0; i < 200; i++) {
            final v = r.nextInt(max);
            expect(v, greaterThanOrEqualTo(0));
            expect(v, lessThan(max));
          }
        }
      }
    });

    test('max of 0 or less gives 0', () {
      final r = StableRandom(3);
      expect(r.nextInt(0), 0);
      expect(r.nextInt(-1), 0);
      expect(r.nextInt(-1000), 0);
    });

    test('a non-positive max does not advance the sequence', () {
      final r = StableRandom(1);
      r.nextInt(0);
      expect(r.nextInt(1000), 542);
    });
  });
}
