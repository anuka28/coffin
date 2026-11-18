// Feature: hauntagotchi-core, Property 14: Steady effort keeps the ghost out of danger
// Validates: Requirements 5.4
import 'package:flutter_test/flutter_test.dart'
    show equals, expect, greaterThanOrEqualTo, group, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/balance.dart';
import 'package:hauntagotchi/src/domain/catch_up.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/ghost_state_rules.dart';
import 'package:hauntagotchi/src/domain/recent_history.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

void main() {
  group('Property 14: steady effort keeps the ghost out of danger', () {
    Glados(
      anyListBetween<DayPlan>(1, 61, anyDayPlan),
      ExploreConfig(numRuns: _numRuns),
    ).test('Health stays at 70 or more and the state is content or thriving', (
      List<DayPlan> raw,
    ) {
      _runs.increment();
      final List<DayPlan> plans = normalizeSteady(raw);
      expect(plans.length, equals(raw.length));

      int health = Balance.maxHealth;
      int idle = 0;
      for (final DayPlan plan in plans) {
        health = CatchUp.settleDay(health, plan.n, plan.c);
        idle = plan.c == 0 ? idle + 1 : 0;
        expect(health, greaterThanOrEqualTo(70), reason: 'after $plan');
        final GhostState state = GhostStateRules.derive(
          health,
          RecentHistory(idleDays: idle),
        );
        expect(
          state == GhostState.content || state == GhostState.thriving,
          isTrue,
          reason: 'state $state at Health $health after $plan',
        );
      }
    });

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });

    test('two bad days in a row, then good days, stay at 70 or more', () {
      int health = Balance.maxHealth;
      for (final DayPlan plan in const <DayPlan>[
        DayPlan(3, 0),
        DayPlan(3, 0),
        DayPlan(3, 3),
      ]) {
        health = CatchUp.settleDay(health, plan.n, plan.c);
        expect(health, greaterThanOrEqualTo(70));
      }
    });
  });
}
