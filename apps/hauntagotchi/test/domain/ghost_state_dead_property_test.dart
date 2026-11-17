// Feature: hauntagotchi-core, Property 5: Dead if and only if Health is zero
// Validates: Requirements 3.3, 3.4, 3.5, 3.7
import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/ghost_state_rules.dart';
import 'package:hauntagotchi/src/domain/recent_history.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

void main() {
  group('Property 5: dead if and only if Health is zero', () {
    Glados2(
      anyHealth,
      anyIntBetween(0, 8),
      ExploreConfig(numRuns: _numRuns),
    ).test('derive is dead exactly when health is 0, and is deterministic', (
      int health,
      int idleDays,
    ) {
      _runs.increment();
      final GhostState first = GhostStateRules.derive(
        health,
        RecentHistory(idleDays: idleDays),
      );
      final GhostState second = GhostStateRules.derive(
        health,
        RecentHistory(idleDays: idleDays),
      );
      expect(first == GhostState.dead, equals(health == 0));
      expect(second, equals(first));
    });

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });
  });
}
