// Feature: graveyard-seance, Property 10: Verdict request facts and seed are stable
// Validates: Requirements 5.2, 5.3, 14.13
import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _factsCounter = RunCounter();
final RunCounter _seedCounter = RunCounter();

void main() {
  group('Property 10: Verdict request facts and seed are stable', () {
    Glados2(
      anyGraveWithSource,
      anySeanceFacts,
      ExploreConfig(numRuns: numRuns),
    ).test('the facts are exactly the name and the day count', (
      Grave grave,
      SeanceFacts facts,
    ) {
      _factsCounter.increment();
      final AiRequest request = buildVerdictRequest(grave: grave, facts: facts);
      expect(request.facts.keys.toSet(), <String>{
        AiFactKeys.projectName,
        AiFactKeys.daysSinceLastCommit,
      });
      expect(request.facts.length, 2);
      expect(request.facts[AiFactKeys.projectName], grave.name);
      expect(request.facts[AiFactKeys.daysSinceLastCommit], facts.dayCount);
    });

    test('ran the facts property the configured number of times', () {
      _factsCounter.expectRuns(numRuns);
    });

    Glados3(
      anyGraveWithSource,
      anySeanceFacts,
      anySeanceFacts,
      ExploreConfig(numRuns: numRuns),
    ).test('the seed depends only on the grave id', (
      Grave grave,
      SeanceFacts first,
      SeanceFacts second,
    ) {
      _seedCounter.increment();
      final AiRequest a = buildVerdictRequest(grave: grave, facts: first);
      final AiRequest b = buildVerdictRequest(grave: grave, facts: second);
      expect(b.seed, a.seed);
      expect(a.seed, inInclusiveRange(0, AiRequest.maxSeed));
    });

    test('ran the seed property the configured number of times', () {
      _seedCounter.expectRuns(numRuns);
    });
  });
}
