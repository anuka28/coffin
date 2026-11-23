import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/grave_ids.dart';

void main() {
  test('starts at g1', () => expect(GraveIds.next(const []), 'g1'));

  test('gives the smallest unused number', () {
    expect(GraveIds.next(['g1', 'g3']), 'g2');
    expect(GraveIds.next(['g1', 'g2']), 'g3');
    expect(GraveIds.next(['other', 'g2']), 'g1');
  });

  test('ignores order and duplicates in the input', () {
    expect(GraveIds.next(['g3', 'g1', 'g1', 'g2']), 'g4');
    expect(GraveIds.next({'g2'}), 'g1');
  });
  test('ignores ids that are not of the form gN', () {
    expect(GraveIds.next(['g', 'G1', 'g01', 'x1']), 'g1');
  });
  test('works with a lazy iterable', () {
    expect(GraveIds.next(['g1', 'g2'].map((e) => e)), 'g3');
  });
  test('the new id is not in the input', () {
    final ids = [for (var i = 1; i <= 20; i++) 'g$i']..remove('g7');
    expect(ids.contains(GraveIds.next(ids)), isFalse);
    expect(GraveIds.next(ids), 'g7');
  });
}
