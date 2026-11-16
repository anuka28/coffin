import 'ping_pong.dart';

/// Slow vertical bob of the ghost, as a pure function of elapsed time.
///
/// The offset starts near zero at time 0, moves down to the amplitude,
/// back up to minus the amplitude and repeats every [periodMs].
final class GhostBob {
  /// Creates a bob.
  ///
  /// [periodMs] is clamped into [minPeriodMs]..[maxPeriodMs] and [amplitude]
  /// into [minAmplitude]..[maxAmplitude]. A NaN amplitude becomes
  /// [defaultAmplitude]. The clamped values are exposed.
  GhostBob({
    int periodMs = defaultPeriodMs,
    double amplitude = defaultAmplitude,
  }) : periodMs = periodMs < minPeriodMs
           ? minPeriodMs
           : (periodMs > maxPeriodMs ? maxPeriodMs : periodMs),
       amplitude = amplitude.isNaN
           ? defaultAmplitude
           : (amplitude < minAmplitude
                 ? minAmplitude
                 : (amplitude > maxAmplitude ? maxAmplitude : amplitude));

  /// Shortest allowed period in milliseconds.
  static const int minPeriodMs = 2500;

  /// Longest allowed period in milliseconds.
  static const int maxPeriodMs = 5000;

  /// Default period in milliseconds.
  static const int defaultPeriodMs = 3600;

  /// Smallest allowed amplitude in logical pixels.
  static const double minAmplitude = 2;

  /// Largest allowed amplitude in logical pixels.
  static const double maxAmplitude = 10;

  /// Default amplitude in logical pixels.
  static const double defaultAmplitude = 6;

  /// Offset used for the static frame under reduced motion.
  static const double staticOffset = 0;

  /// Clamped period in milliseconds.
  final int periodMs;

  /// Clamped amplitude in logical pixels.
  final double amplitude;

  /// Vertical offset in logical pixels, in [-amplitude, amplitude].
  /// Positive is down.
  ///
  /// Domain: `|elapsedMs| <= 2^40`. Negative values wrap with Dart's
  /// non-negative `%`. On the web, values beyond 2^53 have no precision
  /// guarantee but still return an in-range value.
  double offsetAt(int elapsedMs) {
    final phase = (elapsedMs + periodMs ~/ 4) % periodMs;
    return amplitude * (2 * PingPong.at(phase, periodMs) - 1);
  }
}
