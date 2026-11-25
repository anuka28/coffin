// Feature: graveyard-scene, Property 15: Weathering is deterministic
// Validates: Requirements 7.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/weathering.dart';
import 'package:graveyard/src/domain/scene/weathering_result.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 15: Weathering is deterministic', () {
    Glados2(
      anyDayCount,
      anyMixedGraveId,
      ExploreConfig(numRuns: numRuns),
    ).test('two calls with the same arguments return equal results', (
      int dayCount,
      String id,
    ) {
      _counter.increment();
      final WeatheringResult a = Weathering.of(dayCount: dayCount, graveId: id);
      final WeatheringResult b = Weathering.of(dayCount: dayCount, graveId: id);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
