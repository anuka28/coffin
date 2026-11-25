import '../scene/stable_hash.dart';
import '../scene/stable_random.dart';
import 'clod.dart';
import 'play_timing.dart';

/// Generates the deterministic list of Clods for one Grave.
abstract final class ClodPathGenerator {
  /// Fewest Clods a Grave gets.
  static const int minCount = 4;

  /// Most Clods a Grave gets.
  static const int maxCount = 7;

  /// Shortest flight, in milliseconds.
  static const int _minFlightMs = 150;

  /// Number of flight lengths drawn above [_minFlightMs] (150 to 300 ms).
  /// With a launch of at most 300 ms, a clod always lands by 600 ms.
  static const int _flightSpanMs = 151;

  /// Returns 4 to 7 Clods for [graveId], seeded by `StableHash.of(graveId)`
  /// through a `StableRandom`, so the same id always returns an equal list on
  /// every platform.
  static List<Clod> generate(String graveId) {
    final random = StableRandom(StableHash.of(graveId));
    final count = minCount + random.nextInt(maxCount - minCount + 1);
    return List<Clod>.generate(count, (_) => _oneClod(random));
  }

  static Clod _oneClod(StableRandom random) {
    // Integer draws only; doubles come from exact integer divisions.
    final int launchMs = random.nextInt(PlayTiming.handBurstEndMs + 1);
    final int flightMs = _minFlightMs + random.nextInt(_flightSpanMs);
    final double angle = (random.nextInt(1201) - 600) / 1000;
    // Peak is 0.10 to 0.45 of the stone height, so clods stay around the
    // Hand, which reaches 35%.
    final double peak = (10 + random.nextInt(36)) / 100;
    final double size = (2 + random.nextInt(7)).toDouble();
    return Clod(
      launchAngleRadians: angle,
      launchMs: launchMs,
      flightMs: flightMs,
      peakHeightFraction: peak,
      sizePx: size,
    );
  }
}
