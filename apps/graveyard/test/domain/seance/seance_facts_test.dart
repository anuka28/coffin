// Validates: Requirements 2.2, 2.9, 7.4
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';

final CalendarDate _today = CalendarDate(2024, 6, 20);
final CalendarDate _death = CalendarDate(2024, 5, 15);

Grave _github({
  String id = 'g1',
  String name = 'owner/repo',
  CalendarDate? death,
  String? description,
  int stars = 0,
  bool archived = false,
}) => Grave.github(
  id: id,
  name: name,
  dateOfDeath: death ?? _death,
  repo: RepoInfo(
    fullName: 'owner/repo',
    description: description,
    stars: stars,
    archived: archived,
  ),
);

SeanceFacts _facts(Grave grave) => SeanceFacts.of(grave: grave, today: _today);

void main() {
  group('SeanceFacts', () {
    test('a manual grave has no repository facts', () {
      final SeanceFacts facts = _facts(
        Grave.manual(id: 'm1', name: 'Moon Mailer', dateOfDeath: _death),
      );
      expect(facts.archived, isFalse);
      expect(facts.stars, 0);
      expect(facts.hasDescription, isFalse);
      expect(facts.manual, isTrue);
    });

    test('a GitHub grave carries stars, archived and is not manual', () {
      final SeanceFacts facts = _facts(_github(stars: 12, archived: true));
      expect(facts.stars, 12);
      expect(facts.archived, isTrue);
      expect(facts.manual, isFalse);
    });

    test('a GitHub grave with no description has none', () {
      expect(_facts(_github()).hasDescription, isFalse);
    });

    test('a description that cleans to empty counts as none', () {
      expect(
        _facts(_github(description: ':white_check_mark:')).hasDescription,
        isFalse,
      );
      expect(_facts(_github(description: '   \n\t ')).hasDescription, isFalse);
    });

    test('a real description counts', () {
      expect(
        _facts(_github(description: 'The hackable editor')).hasDescription,
        isTrue,
      );
    });

    test('a future date of death gives dayCount 0', () {
      expect(_facts(_github(death: CalendarDate(2025, 1, 1))).dayCount, 0);
    });

    test('a date of death equal to today gives dayCount 0', () {
      expect(_facts(_github(death: _today)).dayCount, 0);
    });

    test('a past date of death gives the elapsed days', () {
      expect(_facts(_github()).dayCount, 36);
    });

    test('facts do not change when only the id or name changes', () {
      final Grave a = _github(description: 'Real', stars: 5);
      final Grave b = _github(
        id: 'other',
        name: 'renamed',
        description: 'Real',
        stars: 5,
      );
      expect(_facts(a), _facts(b));
      final Grave m1 = Grave.manual(id: 'a', name: 'A', dateOfDeath: _death);
      final Grave m2 = Grave.manual(id: 'b', name: 'B', dateOfDeath: _death);
      expect(_facts(m1), _facts(m2));
    });
  });
}
