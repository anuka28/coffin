// Feature: graveyard-core, Property 21: Duplicate rules
// Validates: Requirements 6.8, 6.9, 6.10, 6.11, 6.13
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/duplicate_rules.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_source.dart';
import 'package:graveyard/src/domain/repo_info.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();
final RunCounter _swapCounter = RunCounter();

/// Independent key: trimmed, whitespace runs collapsed, lower-cased.
String _key(String s) => s.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();

/// The compared name of a grave: `full_name` for GitHub, name for manual.
String _compared(Grave g) => g.repo?.fullName ?? g.name;

/// Independent oracle for the duplicate rule.
bool _oracle(Grave candidate, List<Grave> existing) {
  return existing.any((Grave g) {
    if (g.source != candidate.source) return false;
    if (_key(_compared(g)) != _key(_compared(candidate))) return false;
    return candidate.source == GraveSource.github ||
        g.dateOfDeath == candidate.dateOfDeath;
  });
}

/// Same grave with a new name (and `full_name` for GitHub graves).
Grave _renamed(Grave g, String name) {
  final RepoInfo? repo = g.repo;
  if (repo == null) {
    return Grave.manual(id: g.id, name: name, dateOfDeath: g.dateOfDeath);
  }
  return Grave.github(
    id: g.id,
    name: name,
    dateOfDeath: g.dateOfDeath,
    repo: RepoInfo(
      fullName: name,
      htmlUrl: repo.htmlUrl,
      description: repo.description,
      archived: repo.archived,
      stars: repo.stars,
    ),
  );
}

/// Same grave on another day.
Grave _redated(Grave g, CalendarDate date) {
  final RepoInfo? repo = g.repo;
  return repo == null
      ? Grave.manual(id: g.id, name: g.name, dateOfDeath: date)
      : Grave.github(id: g.id, name: g.name, dateOfDeath: date, repo: repo);
}

/// Same grave as the other kind, with the same name and date.
Grave _otherKind(Grave g) {
  final String name = _compared(g);
  return g.source == GraveSource.manual
      ? Grave.github(
          id: g.id,
          name: name,
          dateOfDeath: g.dateOfDeath,
          repo: RepoInfo(fullName: name),
        )
      : Grave.manual(id: g.id, name: name, dateOfDeath: g.dateOfDeath);
}

/// Changes case, pads the edges and repeats inner whitespace.
String _perturb(String name) =>
    ' \t${name.toUpperCase().replaceAll(' ', '   ')}  \n';

void main() {
  group('Property 21: Duplicate rules', () {
    Glados2(anyGraveList, anyGrave, ExploreConfig(numRuns: numRuns)).test(
      'matches the rule, ignores case and whitespace, never mixes kinds',
      (List<Grave> existing, Grave candidate) {
        _counter.increment();
        final bool expected = _oracle(candidate, existing);
        expect(DuplicateRules.isDuplicate(candidate, existing), expected);

        // Case and whitespace never change the answer.
        final Grave noisy = _renamed(candidate, _perturb(_compared(candidate)));
        expect(DuplicateRules.isDuplicate(noisy, existing), expected);
        final List<Grave> noisyExisting = <Grave>[
          for (final Grave g in existing) _renamed(g, _perturb(_compared(g))),
        ];
        expect(DuplicateRules.isDuplicate(candidate, noisyExisting), expected);

        // A grave of the other kind is never a duplicate of it.
        expect(
          DuplicateRules.isDuplicate(_otherKind(candidate), <Grave>[candidate]),
          isFalse,
        );

        // A manual candidate with an equal name and another date differs.
        if (candidate.source == GraveSource.manual) {
          final Grave other = _redated(
            candidate,
            CalendarDate.fromEpochDay(candidate.dateOfDeath.epochDay + 1),
          );
          expect(
            DuplicateRules.isDuplicate(other, <Grave>[candidate]),
            isFalse,
          );
        }

        // Every grave in the list is a duplicate of itself.
        for (final Grave g in existing) {
          expect(DuplicateRules.isDuplicate(g, existing), isTrue);
        }
      },
    );

    Glados2(anyGrave, anyGrave, ExploreConfig(numRuns: numRuns)).test(
      'swapping the roles of two graves gives the same answer',
      (Grave a, Grave b) {
        _swapCounter.increment();
        expect(
          DuplicateRules.isDuplicate(a, <Grave>[b]),
          DuplicateRules.isDuplicate(b, <Grave>[a]),
        );
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
      _swapCounter.expectRuns(numRuns);
    });
  });
}
