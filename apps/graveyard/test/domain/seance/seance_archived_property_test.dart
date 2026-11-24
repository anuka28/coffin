// Feature: graveyard-seance, Property 4: Archived never scores higher
// Validates: Requirements 2.6, 14.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 4: Archived never scores higher', () {
    Glados(anySeanceFacts, ExploreConfig(numRuns: numRuns)).test(
      'archived facts score at most the same facts not archived',
      (SeanceFacts facts) {
        _counter.increment();
        final SeanceFacts live = SeanceFacts(
          dayCount: facts.dayCount,
          archived: false,
          stars: facts.stars,
          hasDescription: facts.hasDescription,
          manual: facts.manual,
        );
        final SeanceFacts archived = SeanceFacts(
          dayCount: facts.dayCount,
          archived: true,
          stars: facts.stars,
          hasDescription: facts.hasDescription,
          manual: facts.manual,
        );

        final int liveScore = SeanceRules.evaluate(live).score;
        final int archivedScore = SeanceRules.evaluate(archived).score;

        expect(archivedScore, lessThanOrEqualTo(liveScore));
        expect(archivedScore, inInclusiveRange(0, 100));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
