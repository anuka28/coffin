import 'fog_frame.dart';

/// Pure functions that map animation progress to fog transition values.
///
/// Progress `t` runs from 0.0 (the incoming page has just started) to 1.0
/// (the page has settled). The math is linear in progress. The easing curve
/// is applied by the widget layer before it calls these functions.
///
/// This class has no Flutter imports so it can be tested without a widget
/// tree.
final class FogMath {
  /// Creates the math with a largest drift of [maxDrift] logical pixels and a
  /// largest blur sigma of [maxBlur] logical pixels.
  const FogMath({
    this.maxDrift = defaultMaxDrift,
    this.maxBlur = defaultMaxBlur,
  }) : assert(maxDrift >= 0, 'maxDrift must not be negative'),
       assert(maxBlur >= 0, 'maxBlur must not be negative');

  /// Default largest vertical drift, in logical pixels.
  static const double defaultMaxDrift = 16;

  /// Default largest blur sigma, in logical pixels.
  static const double defaultMaxBlur = 8;

  /// Shortest transition duration used with normal motion.
  static const Duration minDuration = Duration(milliseconds: 300);

  /// Longest transition duration used with normal motion.
  static const Duration maxDuration = Duration(milliseconds: 600);

  /// Default transition duration.
  static const Duration defaultDuration = Duration(milliseconds: 450);

  /// Vertical drift, in logical pixels, at progress 0.0.
  final double maxDrift;

  /// Blur sigma, in logical pixels, at progress 0.0.
  final double maxBlur;

  /// Clamps [t] into 0.0 to 1.0. NaN becomes 0.0.
  double progress(double t) {
    if (t.isNaN) return 0.0;
    if (t < 0.0) return 0.0;
    if (t > 1.0) return 1.0;
    return t;
  }

  /// Opacity at progress [t], from 0.0 to 1.0.
  ///
  /// Opacity is the same with and without [reducedMotion], so a reduced
  /// motion transition may still be a plain fade.
  double opacity(double t, {bool reducedMotion = false}) => progress(t);

  /// Horizontal drift at progress [t]. Always 0.0.
  double dx(double t, {bool reducedMotion = false}) => 0.0;

  /// Vertical drift at progress [t], from [maxDrift] down to 0.0.
  ///
  /// Returns exactly 0.0 when [reducedMotion] is true.
  double dy(double t, {bool reducedMotion = false}) {
    if (reducedMotion) return 0.0;
    return maxDrift * (1.0 - progress(t));
  }

  /// Blur sigma at progress [t], from [maxBlur] down to 0.0.
  ///
  /// Returns exactly 0.0 when [reducedMotion] is true.
  double blur(double t, {bool reducedMotion = false}) {
    if (reducedMotion) return 0.0;
    return maxBlur * (1.0 - progress(t));
  }

  /// All four values at progress [t] as one [FogFrame].
  FogFrame frame(double t, {bool reducedMotion = false}) => FogFrame(
    opacity: opacity(t, reducedMotion: reducedMotion),
    dx: dx(t, reducedMotion: reducedMotion),
    dy: dy(t, reducedMotion: reducedMotion),
    blur: blur(t, reducedMotion: reducedMotion),
  );

  /// Picks the transition duration.
  ///
  /// With normal motion, [requested] is clamped into [minDuration] to
  /// [maxDuration]. With [reducedMotion], [reducedDuration] is clamped into
  /// zero to [defaultDuration]. It defaults to [Duration.zero], an instant
  /// change.
  Duration resolveDuration(
    Duration requested, {
    bool reducedMotion = false,
    Duration reducedDuration = Duration.zero,
  }) {
    if (reducedMotion) {
      return _clamp(reducedDuration, Duration.zero, defaultDuration);
    }
    return _clamp(requested, minDuration, maxDuration);
  }

  static Duration _clamp(Duration value, Duration low, Duration high) {
    if (value < low) return low;
    if (value > high) return high;
    return value;
  }
}
