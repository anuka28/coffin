import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/stone_point.dart';

void main() {
  group('StonePoint', () {
    test('equal coordinates are equal with the same hashCode', () {
      const StonePoint a = StonePoint(1.5, 2.5);
      const StonePoint b = StonePoint(1.5, 2.5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different x or y are not equal', () {
      const StonePoint a = StonePoint(1, 2);
      expect(a, isNot(const StonePoint(3, 2)));
      expect(a, isNot(const StonePoint(1, 3)));
    });

    test('is not equal to other types', () {
      expect(const StonePoint(1, 2) == Object(), isFalse);
    });
  });
}
