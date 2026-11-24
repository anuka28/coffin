// Feature: graveyard-seance, Property 1: Revival_Score stays in range
// Validates: Requirements 2.1, 2.10, 14.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 1: Revival_Score stays in range', () {
    Glados(anySeanceFacts, ExploreConfig(numRuns: numRuns)).test(
      'the score is an integer from 0 to 100 and the band matches it',
      (SeanceFacts facts) {
        _counter.increment();
        final SeanceResult result = SeanceRules.evaluate(facts);

        expect(result.score, inInclusiveRange(0, 100));
        expect(result.band, RevivalBand.forScore(result.score));
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
