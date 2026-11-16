import 'package:coffin_core/src/ai/seeded_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeededRandom', () {
    const table = <int, List<int>>{
      0: [1144304738, 1416247, 958946056],
      1: [2693262067, 11749833, 2265367787],
      42: [2581720956, 1925393290, 3661312704],
      4294967295: [3850105811, 813802916, 3073704848],
    };

    table.forEach((seed, expected) {
      test('seed $seed gives the reference values', () {
        final r = SeededRandom(seed);
        expect(<int>[r.nextUint32(), r.nextUint32(), r.nextUint32()], expected);
      });
    });

    test('nextInt(1) is always 0', () {
      final r = SeededRandom(7);
      for (var i = 0; i < 200; i++) {
        expect(r.nextInt(1), 0);
      }
    });

    test('nextInt(65536) stays in range', () {
      final r = SeededRandom(4294967295);
      for (var i = 0; i < 500; i++) {
        final v = r.nextInt(65536);
        expect(v >= 0 && v < 65536, isTrue, reason: 'value $v');
      }
    });

    test('same seed gives equal sequences', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);
      for (var i = 0; i < 100; i++) {
        expect(a.nextUint32(), b.nextUint32());
      }
    });

    test('nextInt(0) fails the assert', () {
      expect(() => SeededRandom(1).nextInt(0), throwsA(isA<AssertionError>()));
    });
  });
}
