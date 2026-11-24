// Validates: Requirements 10.1, 10.3, 10.4, 10.5, 10.10
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/scene/tombstone_facts.dart';
import 'package:graveyard/src/domain/scene/tombstone_fragment.dart';
import 'package:graveyard/src/domain/scene/tombstone_fragment_kind.dart';

const String _dateLine = 'Died May 15, 2024';

List<TombstoneFragment> _facts(Grave grave, CalendarDate today) =>
    TombstoneFacts.of(grave: grave, today: today, dateLine: _dateLine);

List<TombstoneFragmentKind> _kinds(List<TombstoneFragment> fragments) => [
  for (final TombstoneFragment f in fragments) f.kind,
];

void main() {
  final CalendarDate death = CalendarDate(2024, 5, 15);
  final CalendarDate today = CalendarDate(2024, 6, 20);
  final String deadFor = DeadForFormatter.format(death, today);

  group('TombstoneFacts', () {
    test('manual grave has title, date line and dead-for only', () {
      final Grave grave = Grave.manual(
        id: 'g1',
        name: 'Moon Mailer',
        dateOfDeath: death,
      );
      expect(_facts(grave, today), [
        const TombstoneFragment(TombstoneFragmentKind.title, 'Moon Mailer'),
        const TombstoneFragment(TombstoneFragmentKind.dateLine, _dateLine),
        TombstoneFragment(TombstoneFragmentKind.deadFor, deadFor),
      ]);
    });

    test(
      'imported grave named like its full_name has no full-name fragment',
      () {
        final Grave grave = Grave.github(
          id: 'g2',
          name: 'owner/repo',
          dateOfDeath: death,
          repo: const RepoInfo(fullName: 'owner/repo'),
        );
        final List<TombstoneFragment> facts = _facts(grave, today);
        expect(facts, hasLength(3));
        expect(_kinds(facts), isNot(contains(TombstoneFragmentKind.fullName)));
        expect(facts.first.text, 'owner/repo');
      },
    );

    test('imported grave with a different name adds the full name', () {
      final Grave grave = Grave.github(
        id: 'g3',
        name: 'repo',
        dateOfDeath: death,
        repo: const RepoInfo(fullName: 'owner/repo'),
      );
      final List<TombstoneFragment> facts = _facts(grave, today);
      expect(facts, hasLength(4));
      expect(
        facts.last,
        const TombstoneFragment(TombstoneFragmentKind.fullName, 'owner/repo'),
      );
      expect(facts.first.text, 'repo');
    });

    test('atom/atom shows the title once and no full-name fragment', () {
      final Grave grave = Grave.github(
        id: 'g4',
        name: 'atom/atom',
        dateOfDeath: death,
        repo: const RepoInfo(fullName: 'atom/atom', stars: 60681),
      );
      final List<TombstoneFragment> facts = _facts(grave, today);
      expect(facts, hasLength(3));
      expect(
        facts.where((TombstoneFragment f) => f.text == 'atom/atom'),
        hasLength(1),
      );
    });

    test('a name equal to the dead-for text still yields each kind once', () {
      final Grave grave = Grave.manual(
        id: 'g5',
        name: deadFor,
        dateOfDeath: death,
      );
      final List<TombstoneFragment> facts = _facts(grave, today);
      final List<TombstoneFragmentKind> kinds = _kinds(facts);
      expect(kinds.toSet(), hasLength(kinds.length));
      expect(kinds, [
        TombstoneFragmentKind.title,
        TombstoneFragmentKind.dateLine,
        TombstoneFragmentKind.deadFor,
      ]);
      expect(facts.first.text, deadFor);
      expect(facts.last.text, deadFor);
    });
  });
}
