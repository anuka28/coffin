import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/raise_rules.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/scene/weathering.dart';

CalendarDate _d(int y, int m, int d) => CalendarDate(y, m, d);

const _repo = RepoInfo(fullName: 'ghost/repo', stars: 3);

Grave _manual({CalendarDate? risenOn, CalendarDate? died}) => Grave.manual(
  id: 'm1',
  name: 'Manual',
  dateOfDeath: died ?? _d(2020, 5, 1),
  risenOn: risenOn,
);

Grave _github({CalendarDate? risenOn, CalendarDate? died}) => Grave.github(
  id: 'g1',
  name: 'Hub',
  dateOfDeath: died ?? _d(2021, 6, 2),
  repo: _repo,
  risenOn: risenOn,
);

void _expectKept(Grave before, Grave after) {
  expect(after.id, before.id);
  expect(after.name, before.name);
  expect(after.dateOfDeath, before.dateOfDeath);
  expect(after.source, before.source);
  expect(after.repo, before.repo);
}

void main() {
  final today = _d(2024, 3, 10);
  final other = _d(2025, 1, 1);

  group('raise', () {
    test('sets risenOn to today on a fresh grave', () {
      expect(RaiseRules.raise(_manual(), today).risenOn, today);
      expect(RaiseRules.raise(_github(), today).risenOn, today);
    });

    test('keeps the first date when already risen', () {
      final risen = RaiseRules.raise(_manual(), today);
      expect(RaiseRules.raise(risen, other).risenOn, today);
      expect(RaiseRules.raise(risen, other), risen);
    });
  });

  group('layToRest', () {
    test('returns an equal grave when not risen', () {
      expect(RaiseRules.layToRest(_manual()), _manual());
      expect(RaiseRules.layToRest(_github()), _github());
    });

    test('clears risenOn on a risen grave', () {
      expect(RaiseRules.layToRest(_manual(risenOn: today)).risenOn, isNull);
      expect(RaiseRules.layToRest(_github(risenOn: today)).risenOn, isNull);
    });
  });

  group('kept fields', () {
    test('raise and layToRest keep id, name, death, source and repo', () {
      for (final grave in [_manual(), _github()]) {
        final raised = RaiseRules.raise(grave, today);
        _expectKept(grave, raised);
        _expectKept(grave, RaiseRules.layToRest(raised));
      }
    });
  });

  group('Grave equality', () {
    test('risenOn takes part in == and hashCode', () {
      final a = _manual();
      final b = _manual(risenOn: today);
      final c = _manual(risenOn: today);
      expect(a, isNot(b));
      expect(b, c);
      expect(b.hashCode, c.hashCode);
      expect(_github(), isNot(_github(risenOn: today)));
      expect(_manual(risenOn: today), isNot(_manual(risenOn: other)));
    });

    test('a grave built without risenOn is not risen', () {
      expect(_manual().risenOn, isNull);
      expect(_github().risenOn, isNull);
    });
  });

  group('day counts', () {
    test('dead-for and weathering input do not change after a raise', () {
      for (final grave in [_manual(), _github()]) {
        final raised = RaiseRules.raise(grave, today);
        expect(
          DeadFor.between(raised.dateOfDeath, today),
          DeadFor.between(grave.dateOfDeath, today),
        );
        final before = grave.dateOfDeath.daysUntil(today);
        final after = raised.dateOfDeath.daysUntil(today);
        expect(after, before);
        expect(
          Weathering.of(dayCount: after, graveId: raised.id),
          Weathering.of(dayCount: before, graveId: grave.id),
        );
      }
    });
  });

  group('extreme dates', () {
    final min = _d(1, 1, 1);
    final max = _d(9999, 12, 31);

    test('no call throws', () {
      for (final date in [min, max]) {
        for (final grave in [
          _manual(died: date),
          _github(died: date),
          _manual(died: date, risenOn: date),
        ]) {
          expect(() => RaiseRules.raise(grave, min), returnsNormally);
          expect(() => RaiseRules.raise(grave, max), returnsNormally);
          expect(() => RaiseRules.layToRest(grave), returnsNormally);
        }
      }
      expect(RaiseRules.raise(_manual(), min).risenOn, min);
      expect(RaiseRules.raise(_manual(), max).risenOn, max);
    });
  });
}
