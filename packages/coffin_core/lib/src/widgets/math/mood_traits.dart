import '../ghost_mood.dart';
import 'eye_style.dart';
import 'mouth_style.dart';

/// The fixed table of numbers that describes one [GhostMood].
///
/// This is the single source of the mood numbers. Painter, loader and tests
/// read it, so no mood number is written twice.
final class MoodTraits {
  /// Creates one table row.
  const MoodTraits({
    required this.eyes,
    required this.mouth,
    required this.lean,
    required this.droop,
    required this.opacity,
    required this.bobPeriodMs,
    required this.bobAmplitude,
  });

  /// The eye shape of the mood.
  final EyeStyle eyes;

  /// The mouth shape of the mood.
  final MouthStyle mouth;

  /// Tilt in radians. Positive tilts clockwise.
  final double lean;

  /// Signed droop. Positive squashes the body towards the hem and widens it,
  /// negative stretches it.
  final double droop;

  /// Body opacity from 0 to 1.
  final double opacity;

  /// Bob period in milliseconds.
  final int bobPeriodMs;

  /// Bob amplitude in logical pixels. 0 means no bob.
  final double bobAmplitude;

  /// The largest bob amplitude of any mood, in logical pixels.
  static const double maxBobAmplitude = 8;

  /// The largest scale of the `fed` reaction.
  static const double fedMaxScale = 1.10;

  /// The largest lift of the `fed` reaction, in logical pixels.
  static const double fedMaxLift = 6;

  /// The largest lift of the `rising` reaction, in logical pixels.
  static const double risingMaxLift = 10;

  /// The largest lean in radians.
  static const double maxLean = 0.15;

  /// Extra room for the pop of `fed`, as a fraction of the ghost height.
  static const double popReserve = 0.05;

  /// Extra room for the stretch of `rising`, as a fraction of the ghost
  /// height.
  static const double stretchReserve = 0.06;

  static const MoodTraits _thriving = MoodTraits(
    eyes: EyeStyle.wide,
    mouth: MouthStyle.smile,
    lean: 0,
    droop: 0,
    opacity: 1.00,
    bobPeriodMs: 3000,
    bobAmplitude: 8,
  );

  static const MoodTraits _content = MoodTraits(
    eyes: EyeStyle.round,
    mouth: MouthStyle.gentleSmile,
    lean: 0,
    droop: 0,
    opacity: 0.92,
    bobPeriodMs: 3600,
    bobAmplitude: 6,
  );

  static const MoodTraits _hungry = MoodTraits(
    eyes: EyeStyle.droopy,
    mouth: MouthStyle.smallOpen,
    lean: 0.04,
    droop: 0.03,
    opacity: 0.85,
    bobPeriodMs: 4400,
    bobAmplitude: 4,
  );

  static const MoodTraits _fading = MoodTraits(
    eyes: EyeStyle.halfClosed,
    mouth: MouthStyle.flat,
    lean: 0.06,
    droop: 0.07,
    opacity: 0.78,
    bobPeriodMs: 5000,
    bobAmplitude: 2,
  );

  static const MoodTraits _dead = MoodTraits(
    eyes: EyeStyle.cross,
    mouth: MouthStyle.none,
    lean: 0.15,
    droop: 0.10,
    opacity: 0.72,
    bobPeriodMs: 5000,
    bobAmplitude: 0,
  );

  static const MoodTraits _fed = MoodTraits(
    eyes: EyeStyle.happyArc,
    mouth: MouthStyle.wideSmile,
    lean: 0,
    droop: 0,
    opacity: 1.00,
    bobPeriodMs: 3000,
    bobAmplitude: 8,
  );

  static const MoodTraits _rising = MoodTraits(
    eyes: EyeStyle.wide,
    mouth: MouthStyle.smallOpen,
    lean: 0,
    droop: -0.06,
    opacity: 1.00,
    bobPeriodMs: 3000,
    bobAmplitude: 8,
  );

  /// Returns the table row of [mood].
  static MoodTraits of(GhostMood mood) {
    switch (mood) {
      case GhostMood.thriving:
        return _thriving;
      case GhostMood.content:
        return _content;
      case GhostMood.hungry:
        return _hungry;
      case GhostMood.fading:
        return _fading;
      case GhostMood.dead:
        return _dead;
      case GhostMood.fed:
        return _fed;
      case GhostMood.rising:
        return _rising;
    }
  }

  /// Vertical room, in logical pixels, kept above and below a ghost of
  /// [size].
  ///
  /// The size is clamped into 24 to 256 (NaN becomes 64) and the result is
  /// `ceil(8 + 10 + 0.06 * size)`.
  static int reserveFor(double size) {
    final double s = size.isNaN
        ? 64
        : (size < 24 ? 24 : (size > 256 ? 256 : size));
    final double exact = maxBobAmplitude + risingMaxLift + stretchReserve * s;
    final int whole = exact.toInt();
    return whole < exact ? whole + 1 : whole;
  }
}
