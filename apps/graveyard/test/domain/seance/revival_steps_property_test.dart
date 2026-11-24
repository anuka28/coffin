// Feature: graveyard-seance, Property 12: A manual Grave never gets a repository-only step
// Validates: Requirements 4.1, 4.2, 4.11
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/seance/revival_steps.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Facts of a manual Grave with any archived, stars and description values,
/// so that the property also covers inconsistent inputs.
Generator<SeanceFacts> get _anyManualAnyFlags => anySeanceFacts.map(
  (SeanceFacts f) => SeanceFacts(
    dayCount: f.dayCount,
    archived: f.archived,
    stars: f.stars,
    hasDescription: f.hasDescription,
    manual: true,
  ),
);

void main() {
  group('Property 12: A manual Grave never gets a repository-only step', () {
    Glados(_anyManualAnyFlags, ExploreConfig(numRuns: numRuns)).test(
      'no skimReadme, no forkRepository, still three distinct kinds',
      (SeanceFacts facts) {
        _counter.increment();
        final List<RevivalStepKind> steps = RevivalSteps.choose(facts);
        expect(steps, hasLength(3), reason: '$facts');
        expect(steps.toSet(), hasLength(3), reason: '$facts');
        expect(steps, isNot(contains(RevivalStepKind.skimReadme)));
        expect(steps, isNot(contains(RevivalStepKind.forkRepository)));
        expect(SeanceRules.evaluate(facts).steps, steps, reason: '$facts');
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('an archived manual fact still gets no repository-only step', () {
      const SeanceFacts facts = SeanceFacts(
        dayCount: 4015,
        archived: true,
        stars: 50,
        hasDescription: true,
        manual: true,
      );
      expect(RevivalSteps.choose(facts), <RevivalStepKind>[
        RevivalStepKind.writeDownPurpose,
        RevivalStepKind.updateDependencies,
        RevivalStepKind.fixOneThing,
      ]);
    });
  });
}
