import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/living_split.dart';
import 'package:graveyard/src/domain/raise_rules.dart';

Grave _plain(String id, [String? name]) => Grave.manual(
  id: id,
  name: name ?? 'Grave $id',
  dateOfDeath: CalendarDate(2024, 1, 1),
);

Grave _risen(String id, CalendarDate on, [String? name]) =>
    RaiseRules.raise(_plain(id, name), on);

List<String> _ids(List<Grave> graves) => [for (final g in graves) g.id];

void main() {
  group('LivingSplit.split', () {
    test('splits a list with risen, playing and plain graves', () {
      final plain1 = _plain('p1');
      final risenOld = _risen('r1', CalendarDate(2025, 1, 5));
      final playing = _risen('r2', CalendarDate(2025, 2, 1));
      final risenNew = _risen('r3', CalendarDate(2025, 3, 1));
      final plain2 = _plain('p2');

      final (rows, living) = LivingSplit.split(
        graves: [plain1, risenOld, playing, risenNew, plain2],
        playing: {'r2'},
      );

      expect(_ids(rows), ['p1', 'r2', 'p2']);
      expect(_ids(living), ['r3', 'r1']);
    });

    test('a risen grave that is playing stays in the graveyard rows', () {
      final g = _risen('a', CalendarDate(2025, 1, 1));
      final (rows, living) = LivingSplit.split(graves: [g], playing: {'a'});
      expect(rows, [g]);
      expect(living, isEmpty);
    });

    test('graveyard rows keep the input order', () {
      final graves = [
        _plain('z'),
        _plain('b'),
        _risen('r', CalendarDate(2025, 1, 1)),
        _plain('m'),
        _plain('a'),
      ];
      final (rows, _) = LivingSplit.split(graves: graves, playing: {});
      expect(_ids(rows), ['z', 'b', 'm', 'a']);
    });

    test('two risen graves order most recent first', () {
      final older = _risen('a', CalendarDate(2025, 1, 1));
      final newer = _risen('b', CalendarDate(2025, 2, 1));
      final (_, living) = LivingSplit.split(
        graves: [older, newer],
        playing: {},
      );
      expect(_ids(living), ['b', 'a']);
    });

    test('a tie on date is broken by lower-cased name', () {
      final day = CalendarDate(2025, 1, 1);
      final (_, living) = LivingSplit.split(
        graves: [
          _risen('1', day, 'beta'),
          _risen('2', day, 'Alpha'),
          _risen('3', day, 'ZED'),
        ],
        playing: {},
      );
      expect(_ids(living), ['2', '1', '3']);
    });

    test('a tie on date and name is broken by id', () {
      final day = CalendarDate(2025, 1, 1);
      final (_, living) = LivingSplit.split(
        graves: [
          _risen('c', day, 'Same'),
          _risen('a', day, 'same'),
          _risen('b', day, 'SAME'),
        ],
        playing: {},
      );
      expect(_ids(living), ['a', 'b', 'c']);
    });

    test('a tie on risenOn is broken by most recent date of death first', () {
      final day = CalendarDate(2025, 1, 1);
      Grave died(String id, CalendarDate death) => RaiseRules.raise(
        Grave.manual(id: id, name: 'Same', dateOfDeath: death),
        day,
      );
      final (_, living) = LivingSplit.split(
        graves: [
          died('a', CalendarDate(2023, 1, 1)),
          died('b', CalendarDate(2024, 6, 1)),
        ],
        playing: {},
      );
      expect(_ids(living), ['b', 'a']);
    });

    test('an empty list returns two empty lists', () {
      final (rows, living) = LivingSplit.split(graves: [], playing: {});
      expect(rows, isEmpty);
      expect(living, isEmpty);
    });

    test('playing ids that are not in the list are ignored', () {
      final plain = _plain('p');
      final risen = _risen('r', CalendarDate(2025, 1, 1));
      final (rows, living) = LivingSplit.split(
        graves: [plain, risen],
        playing: {'ghost', 'other'},
      );
      expect(rows, [plain]);
      expect(living, [risen]);
    });

    test('a list where every grave is risen leaves no graveyard rows', () {
      final (rows, living) = LivingSplit.split(
        graves: [
          _risen('a', CalendarDate(2025, 1, 1)),
          _risen('b', CalendarDate(2025, 1, 2)),
        ],
        playing: {},
      );
      expect(rows, isEmpty);
      expect(_ids(living), ['b', 'a']);
    });
  });
}
