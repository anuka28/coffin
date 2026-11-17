// Feature: hauntagotchi-core, Property 6: Lower Health is never healthier
// Validates: Requirements 3.6
import 'package:flutter_test/flutter_test.dart'
    show expect, group, lessThanOrEqualTo, test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/ghost_state_rules.dart';
import 'package:hauntagotchi/src/domain/recent_history.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 200;
final RunCounter _runs = RunCounter();

void main() {
  group('Property 6: lower Health is never healthier', () {
    Glados3(
      anyHealth,
      anyHealth,
      anyIntBetween(0, 8),
      ExploreConfig(numRuns: _numRuns),
    ).test('a <= b implies derive(a).index <= derive(b).index', (
      int x,
      int y,
      int idleDays,
    ) {
      _runs.increment();
      final int a = x <= y ? x : y;
      final int b = x <= y ? y : x;
      final RecentHistory history = RecentHistory(idleDays: idleDays);
      final GhostState low = GhostStateRules.derive(a, history);
      final GhostState high = GhostStateRules.derive(b, history);
      expect(
        low.index,
        lessThanOrEqualTo(high.index),
        reason: 'health $a gave $low but health $b gave $high',
      );
    });

    test('the property body ran numRuns times', () {
      _runs.expectRuns(_numRuns);
    });
  });
}
