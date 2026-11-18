import '../ghost_mood.dart';
import 'mood_traits.dart';

/// An immutable pose of the ghost: a weighted mix of mood table rows plus the
/// numbers that animate.
///
/// Every transition and every reaction is a blend between two poses. There is
/// no blended bob period, only a blended bob amplitude.
final class MoodPose {
  /// Creates a pose from raw values, for blend results.
  ///
  /// [weights] must hold 7 values indexed by `GhostMood.index`, each in 0 to
  /// 1 and summing to 1. The caller passes an unmodifiable list.
  const MoodPose({
    required this.weights,
    required this.opacity,
    required this.lean,
    required this.droop,
    required this.scale,
    required this.lift,
    required this.bobAmplitude,
  }) : assert(weights.length == 7, 'A pose has one weight per mood');

  /// The resting pose of [mood]: weight 1 on the mood, the table numbers,
  /// scale 1 and lift 0.
  factory MoodPose.rest(GhostMood mood) {
    final MoodTraits t = MoodTraits.of(mood);
    return MoodPose(
      weights: List<double>.unmodifiable(<double>[
        for (final GhostMood m in GhostMood.values) m == mood ? 1.0 : 0.0,
      ]),
      opacity: t.opacity,
      lean: t.lean,
      droop: t.droop,
      scale: 1,
      lift: 0,
      bobAmplitude: t.bobAmplitude,
    );
  }

  /// Weight of each mood, indexed by `GhostMood.index`.
  final List<double> weights;

  /// Body opacity from 0 to 1.
  final double opacity;

  /// Tilt in radians. Positive tilts clockwise.
  final double lean;

  /// Signed droop. Positive squashes and widens, negative stretches.
  final double droop;

  /// Scale about the center of the body. 1 is the resting size.
  final double scale;

  /// Upward lift in logical pixels.
  final double lift;

  /// Blended bob amplitude in logical pixels.
  final double bobAmplitude;

  /// Returns a copy with the named numbers replaced. Weights, lean, droop and
  /// bob amplitude are kept.
  MoodPose copyWith({double? opacity, double? scale, double? lift}) {
    return MoodPose(
      weights: weights,
      opacity: opacity ?? this.opacity,
      lean: lean,
      droop: droop,
      scale: scale ?? this.scale,
      lift: lift ?? this.lift,
      bobAmplitude: bobAmplitude,
    );
  }

  static double _clampSize(double size) {
    if (size.isNaN) {
      return 64;
    }
    return size < 24 ? 24 : (size > 256 ? 256 : size);
  }

  static double _abs(double v) => v < 0 ? -v : v;

  static double _finite(double v) => v.isNaN ? 0 : v;

  /// Upper bound, in logical pixels, of how far the body reaches above its
  /// rest rectangle for a ghost of [size], excluding the bob.
  ///
  /// [size] is clamped into 24 to 256 (NaN becomes 64). The bound is the lift
  /// plus half the scale growth, the stretch and the tilt, all linear.
  double upwardReach(double size) {
    final double s = _clampSize(size);
    final double growth = scale > 1 ? 0.5 * s * (scale - 1) : 0;
    final double stretch = droop < 0 ? s * -droop : 0;
    final double tilt = 0.4 * s * _abs(lean);
    final double total = (lift > 0 ? lift : 0) + growth + stretch + tilt;
    return _finite(total);
  }

  /// Upper bound, in logical pixels, of how far the body reaches below its
  /// rest rectangle for a ghost of [size], excluding the bob.
  ///
  /// [size] is clamped into 24 to 256 (NaN becomes 64). The bound is half the
  /// scale growth plus the tilt. Lift and stretch only move the body up.
  double downwardReach(double size) {
    final double s = _clampSize(size);
    final double growth = scale > 1 ? 0.5 * s * (scale - 1) : 0;
    final double tilt = 0.4 * s * _abs(lean);
    return _finite(growth + tilt);
  }

  /// Upper bound, in logical pixels, of the half width of the body measured
  /// from its center line for a ghost of [size].
  ///
  /// This is the whole half extent, not only the part beyond the rest
  /// rectangle: half the rest width (`0.4 * size`) scaled, plus the tilt and
  /// the widening of a positive droop. [size] is clamped into 24 to 256 (NaN
  /// becomes 64).
  double horizontalReach(double size) {
    final double s = _clampSize(size);
    final double half = 0.4 * s * (scale > 1 ? scale : 1);
    final double tilt = 0.5 * s * _abs(lean);
    final double widen = droop > 0 ? 0.2 * s * droop : 0;
    return _finite(half + tilt + widen);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! MoodPose ||
        other.opacity != opacity ||
        other.lean != lean ||
        other.droop != droop ||
        other.scale != scale ||
        other.lift != lift ||
        other.bobAmplitude != bobAmplitude ||
        other.weights.length != weights.length) {
      return false;
    }
    for (int i = 0; i < weights.length; i++) {
      if (other.weights[i] != weights[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(weights),
    opacity,
    lean,
    droop,
    scale,
    lift,
    bobAmplitude,
  );

  @override
  String toString() =>
      'MoodPose(weights: $weights, opacity: $opacity, lean: $lean, '
      'droop: $droop, scale: $scale, lift: $lift, '
      'bobAmplitude: $bobAmplitude)';
}
