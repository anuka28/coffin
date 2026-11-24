// Feature: graveyard-seance, Property 2: Evaluation is deterministic
// Validates: Requirements 2.4, 7.4, 14.5
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _factsCounter = RunCounter();
final RunCounter _nameCounter = RunCounter();

/// A fixed Today, so no test reads a clock.
final CalendarDate _today = CalendarDate(2026, 5, 10);

/// [grave] with a new [name] and [id]; everything else is kept.
Grave _renamed(Grave grave, {required String name, required String id}) {
  final repo = grave.repo;
  return repo == null
      ? Grave.manual(id: id, name: name, dateOfDeath: grave.dateOfDeath)
      : Grave.github(
          id: id,
          name: name,
          dateOfDeath: grave.dateOfDeath,
          repo: repo,
        );
}

void _expectNameIndependent(Grave grave, String otherName, String otherId) {
  final Grave nameOnly = _renamed(grave, name: otherName, id: grave.id);
  final Grave nameAndId = _renamed(grave, name: otherName, id: otherId);
  final SeanceFacts facts = SeanceFacts.of(grave: grave, today: _today);
  final SeanceResult result = SeanceRules.evaluate(facts);

  for (final Grave other in <Grave>[nameOnly, nameAndId]) {
    final SeanceFacts otherFacts = SeanceFacts.of(grave: other, today: _today);
    expect(otherFacts, facts, reason: '${grave.name} vs ${other.name}');
    expect(SeanceRules.evaluate(otherFacts), result);
  }
}

void main() {
  group('Property 2: Evaluation is deterministic', () {
    Glados(anySeanceFacts, ExploreConfig(numRuns: numRuns)).test(
      'the same facts give an equal result twice',
      (SeanceFacts facts) {
        _factsCounter.increment();
        final SeanceResult first = SeanceRules.evaluate(facts);
        final SeanceResult second = SeanceRules.evaluate(facts);
        expect(second, first);
        expect(second.score, first.score);
        expect(second.band, first.band);
        expect(second.steps, first.steps);
      },
    );

    test('ran the configured number of times', () {
      _factsCounter.expectRuns(numRuns);
    });

    Glados2(
      anyGraveWithSource,
      anyGraveWithSource,
      ExploreConfig(numRuns: numRuns),
    ).test('the score does not depend on the grave name or id', (
      Grave grave,
      Grave other,
    ) {
      _nameCounter.increment();
      _expectNameIndependent(grave, other.name, other.id);
    });

    test('ran the name property the configured number of times', () {
      _nameCounter.expectRuns(numRuns);
    });

    group('pinned names', () {
      final List<String> names = <String>[
        'my cool project',
        '  spaced   out  ',
        'élan café ñandú',
        'Åsa über',
        '👻',
        'ghost 👻 haunts 🎃',
        'a',
        'x' * 80,
      ];
      final List<Grave> graves = <Grave>[
        Grave.manual(
          id: 'g1',
          name: 'plain',
          dateOfDeath: CalendarDate(2025, 3, 1),
        ),
        Grave.manual(
          id: 'g2',
          name: 'old',
          dateOfDeath: CalendarDate(2010, 1, 1),
        ),
      ];

      for (final Grave grave in graves) {
        for (final String name in names) {
          test('${grave.id} renamed to "$name" scores the same', () {
            _expectNameIndependent(grave, name, 'other-id');
          });
        }
      }
    });
  });
}
