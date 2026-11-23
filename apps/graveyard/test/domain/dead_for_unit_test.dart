import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/dead_for_unit.dart';

void main() {
  test('units run from youngest to oldest', () {
    expect(DeadForUnit.values, [
      DeadForUnit.today,
      DeadForUnit.days,
      DeadForUnit.weeks,
      DeadForUnit.months,
      DeadForUnit.years,
    ]);
  });

  test('index grows with age', () {
    for (var i = 1; i < DeadForUnit.values.length; i++) {
      expect(
        DeadForUnit.values[i].index,
        greaterThan(DeadForUnit.values[i - 1].index),
      );
    }
  });
}
