import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_sorter.dart';

Grave _g(String id, String name, int day) =>
    Grave.manual(id: id, name: name, dateOfDeath: CalendarDate(2025, 3, day));

void main() {
  test('orders by date descending', () {
    final sorted = GraveSorter.sort([_g('g1', 'a', 1), _g('g2', 'b', 5)]);
    expect(sorted.map((g) => g.id), ['g2', 'g1']);
  });

  test('ties break by lower-cased name, then id', () {
    final sorted = GraveSorter.sort([
      _g('g3', 'beta', 2),
      _g('g2', 'Alpha', 2),
      _g('g1', 'alpha', 2),
    ]);
    expect(sorted.map((g) => g.id), ['g1', 'g2', 'g3']);
  });

  test('returns a new list and leaves the input untouched', () {
    final input = [_g('g1', 'a', 1), _g('g2', 'b', 5)];
    final sorted = GraveSorter.sort(input);
    expect(input.map((g) => g.id), ['g1', 'g2']);
    expect(identical(sorted, input), isFalse);
  });

  test('an empty list gives an empty list', () {
    expect(GraveSorter.sort(const []), isEmpty);
  });
  test('the same name and date break the tie by id', () {
    final sorted = GraveSorter.sort([_g('g2', 'a', 2), _g('g10', 'a', 2)]);
    expect(sorted.map((g) => g.id), ['g10', 'g2']);
  });
  test('date wins over name', () {
    final sorted = GraveSorter.sort([_g('g1', 'a', 1), _g('g2', 'z', 9)]);
    expect(sorted.map((g) => g.id), ['g2', 'g1']);
  });
  test('keeps every grave', () {
    final input = [_g('g1', 'a', 1), _g('g2', 'a', 1), _g('g3', 'b', 2)];
    expect(GraveSorter.sort(input).toSet(), input.toSet());
  });
  test('the order does not depend on the input order', () {
    final input = [_g('g1', 'b', 1), _g('g2', 'a', 1), _g('g3', 'c', 4)];
    expect(
      GraveSorter.sort(input.reversed).map((g) => g.id),
      GraveSorter.sort(input).map((g) => g.id),
    );
  });
}
