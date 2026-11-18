import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ritual_progress.dart';

void main() {
  group('RitualProgress', () {
    test('isComplete when done reaches needed', () {
      expect(const RitualProgress(done: 0, needed: 2).isComplete, isFalse);
      expect(const RitualProgress(done: 1, needed: 2).isComplete, isFalse);
      expect(const RitualProgress(done: 2, needed: 2).isComplete, isTrue);
      expect(const RitualProgress(done: 3, needed: 2).isComplete, isTrue);
    });

    test('equal values share equality and hashCode', () {
      const RitualProgress a = RitualProgress(done: 1, needed: 2);
      const RitualProgress b = RitualProgress(done: 1, needed: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different values are not equal', () {
      const RitualProgress a = RitualProgress(done: 1, needed: 2);
      expect(a, isNot(const RitualProgress(done: 2, needed: 2)));
      expect(a, isNot(const RitualProgress(done: 1, needed: 1)));
    });
  });
}
