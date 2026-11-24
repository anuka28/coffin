// Feature: graveyard-seance, Property 7: Exactly three distinct steps
// Validates: Requirements 4.1, 4.2, 14.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/seance/revival_steps.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 7: Exactly three distinct steps', () {
    Glados(anySeanceFacts, ExploreConfig(numRuns: numRuns)).test(
      'choose returns three pairwise distinct kinds and evaluate agrees',
      (SeanceFacts facts) {
        _counter.increment();
        final List<RevivalStepKind> steps = RevivalSteps.choose(facts);
        expect(steps, hasLength(3), reason: '$facts');
        expect(steps.toSet(), hasLength(3), reason: '$facts');
        expect(SeanceRules.evaluate(facts).steps, steps, reason: '$facts');
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
