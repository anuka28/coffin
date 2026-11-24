// Feature: graveyard-scene, Property 14: Tilt and fade stay within their limits
// Validates: Requirements 7.5, 7.6
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/weathering.dart';
import 'package:graveyard/src/domain/scene/weathering_result.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Float tolerance around the exact bounds.
const double _epsilon = 1e-9;

/// Three degrees in radians.
final double _maxTilt = 3 * math.pi / 180;

void main() {
  group('Property 14: Tilt and fade stay within their limits', () {
    Glados3(
      anyDayCount,
      anyDayCount,
      anyGraveId,
      ExploreConfig(numRuns: numRuns),
    ).test('tilt is within 3 degrees and level * 3 degrees, fade is within '
        '[0, 0.25] and never decreases with the day count', (
      int dayA,
      int dayB,
      String id,
    ) {
      _counter.increment();
      final int lo = math.min(dayA, dayB);
      final int hi = math.max(dayA, dayB);
      final WeatheringResult a = Weathering.of(dayCount: lo, graveId: id);
      final WeatheringResult b = Weathering.of(dayCount: hi, graveId: id);

      for (final WeatheringResult r in <WeatheringResult>[a, b]) {
        expect(r.tiltRadians.isFinite, isTrue);
        expect(r.tiltRadians.abs(), lessThanOrEqualTo(_maxTilt + _epsilon));
        expect(
          r.tiltRadians.abs(),
          lessThanOrEqualTo(r.level * _maxTilt + _epsilon),
        );
        expect(r.fade, greaterThanOrEqualTo(0));
        expect(r.fade, lessThanOrEqualTo(0.25 + _epsilon));
      }
      expect(b.fade, greaterThanOrEqualTo(a.fade));
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
