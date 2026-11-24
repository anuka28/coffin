import 'dart:math' as math;

import 'stable_hash.dart';
import 'weathering_result.dart';

/// Computes how weathered a tombstone looks from the age of its project.
abstract final class Weathering {
  /// Day count at which a stone is fully weathered.
  static const int weatheringCeilingDays = 3650;

  /// Largest tilt of a stone, in degrees.
  static const double maxTiltDegrees = 3;

  /// Largest fade of a stone.
  static const double maxFade = 0.25;

  /// Returns the weathering for a project dead for [dayCount] days.
  ///
  /// A negative [dayCount] counts as 0. The tilt direction depends only on
  /// [graveId], through [StableHash.of].
  static WeatheringResult of({required int dayCount, required String graveId}) {
    final level = (math.max(0, dayCount) / weatheringCeilingDays)
        .clamp(0.0, 1.0)
        .toDouble();
    final sign = StableHash.of(graveId).isEven ? 1.0 : -1.0;
    final tilt = level * maxTiltDegrees * math.pi / 180 * sign;
    return WeatheringResult(
      level: level,
      tiltRadians: tilt,
      fade: level * maxFade,
    );
  }
}
