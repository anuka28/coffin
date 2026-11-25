// Feature: graveyard-resurrection, Property 1: Raise then Lay_To_Rest returns the original Grave
// Validates: Requirements 2.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/raise_rules.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 1: Raise then Lay_To_Rest returns the original Grave', () {
    Glados2(
      anyGraveWithRisen,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test('laying a raised Grave to rest gives back the original', (
      Grave generated,
      CalendarDate today,
    ) {
      _counter.increment();
      // A Grave that is not Risen.
      final Grave original = RaiseRules.layToRest(generated);
      expect(original.risenOn, isNull);

      final Grave raised = RaiseRules.raise(original, today);
      expect(raised.risenOn, today);

      final Grave restored = RaiseRules.layToRest(raised);
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
