// Feature: graveyard-seance, Property 3: Older death never scores higher
// Validates: Requirements 2.5, 14.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

SeanceFacts _withDays(SeanceFacts facts, int dayCount) => SeanceFacts(
  dayCount: dayCount,
  archived: facts.archived,
  stars: facts.stars,
  hasDescription: facts.hasDescription,
  manual: facts.manual,
);

void main() {
  group('Property 3: Older death never scores higher', () {
    Glados3(
      anySeanceFacts,
      anyIntBetween(0, 20001),
      anyIntBetween(0, 20001),
      ExploreConfig(numRuns: numRuns),
    ).test('with every other fact equal, more days never give a higher score', (
      SeanceFacts facts,
      int a,
      int b,
    ) {
      _counter.increment();
      // Mix the generated day count in so the edge values are also tried.
      final int first = facts.dayCount;
      final int second = (a + b) % 20001;
      final int newer = first < second ? first : second;
      final int older = first < second ? second : first;

      final int newerScore = SeanceRules.evaluate(_withDays(facts, newer))
          .score;
      final int olderScore = SeanceRules.evaluate(_withDays(facts, older))
          .score;

      expect(olderScore, lessThanOrEqualTo(newerScore));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
