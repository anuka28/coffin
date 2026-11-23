import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/duplicate_rules.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';

Grave _manual(String id, String name, int day) =>
    Grave.manual(id: id, name: name, dateOfDeath: CalendarDate(2025, 3, day));

Grave _github(String id, String fullName) => Grave.github(
  id: id,
  name: fullName,
  dateOfDeath: CalendarDate(2025, 3, 1),
  repo: RepoInfo(fullName: fullName),
);

void main() {
  test('GitHub graves match by full_name, ignoring case and spaces', () {
    expect(
      DuplicateRules.isDuplicate(_github('g2', ' Octo/Repo '), [
        _github('g1', 'octo/repo'),
      ]),
      isTrue,
    );
    expect(
      DuplicateRules.isDuplicate(_github('g2', 'octo/other'), [
        _github('g1', 'octo/repo'),
      ]),
      isFalse,
    );
  });

  test('manual graves match by name key and date', () {
    final existing = [_manual('g1', 'My  App', 4)];
    expect(
      DuplicateRules.isDuplicate(_manual('g2', 'my app', 4), existing),
      isTrue,
    );
    expect(
      DuplicateRules.isDuplicate(_manual('g2', 'my app', 5), existing),
      isFalse,
    );
  });

  test('never compares across sources', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g2', 'octo/repo', 1), [
        _github('g1', 'octo/repo'),
      ]),
      isFalse,
    );
    expect(
      DuplicateRules.isDuplicate(_github('g2', 'octo/repo'), [
        _manual('g1', 'octo/repo', 1),
      ]),
      isFalse,
    );
  });

  test('an empty list never holds a duplicate', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g1', 'x', 1), const []),
      isFalse,
    );
    expect(DuplicateRules.isDuplicate(_github('g1', 'a/b'), const []), isFalse);
  });
  test('GitHub graves ignore the date and repeated whitespace', () {
    final other = Grave.github(
      id: 'g1',
      name: 'a/b',
      dateOfDeath: CalendarDate(2020, 1, 1),
      repo: const RepoInfo(fullName: 'a/b'),
    );
    expect(DuplicateRules.isDuplicate(_github('g2', 'A/B'), [other]), isTrue);
  });
  test('GitHub graves match by full_name, not by display name', () {
    final cut = Grave.github(
      id: 'g2',
      name: 'short',
      dateOfDeath: CalendarDate(2025, 3, 1),
      repo: const RepoInfo(fullName: 'octo/repo'),
    );
    expect(
      DuplicateRules.isDuplicate(cut, [_github('g1', 'octo/repo')]),
      isTrue,
    );
  });
  test('manual graves with the same name on another date are kept', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g2', 'x', 1), [
        _manual('g1', 'x', 2),
      ]),
      isFalse,
    );
  });
  test('manual graves with the same date and another name are kept', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g2', 'y', 1), [
        _manual('g1', 'x', 1),
      ]),
      isFalse,
    );
  });
  test('the id plays no part', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g1', 'x', 1), [
        _manual('g1', 'x', 1),
      ]),
      isTrue,
    );
  });
  test('any one match in the list is enough', () {
    expect(
      DuplicateRules.isDuplicate(_manual('g9', 'x', 1), [
        _manual('g1', 'a', 1),
        _github('g2', 'x'),
        _manual('g3', 'X', 1),
      ]),
      isTrue,
    );
  });
}
