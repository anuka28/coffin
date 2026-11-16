import '../../common/seeded_random.dart';

/// A looping, seeded brightness schedule for flickering text.
///
/// The schedule has 16 levels, 400 ms apart, that loop every 6400 ms. Each
/// level is a whole percent from 75 to 100. Between two levels the opacity
/// follows a smoothstep curve, and the last step eases back to level 0.
///
/// All math uses exact integer numerators and one division, so the result is
/// the same on the Dart VM and on Flutter Web.
final class FlickerSchedule {
  /// Builds the schedule for [seed].
  ///
  /// A [seed] outside 0..4294967295 is masked with 0xFFFFFFFF, so it never
  /// throws and gives the same schedule as `seed & 0xFFFFFFFF`.
  factory FlickerSchedule(int seed) {
    final int masked = seed & 0xFFFFFFFF;
    final SeededRandom random = SeededRandom(masked);
    final List<int> percents = <int>[
      for (int i = 0; i < levelCount; i++)
        minPercent + random.nextInt(maxPercent - minPercent + 1),
    ];

    // Repair 1: keep a visible dip.
    int minIndex = 0;
    for (int i = 1; i < levelCount; i++) {
      if (percents[i] < percents[minIndex]) minIndex = i;
    }
    if (percents[minIndex] > 90) percents[minIndex] = 85;

    // Repair 2: return to full brightness at least once.
    int maxIndex = 0;
    for (int i = 1; i < levelCount; i++) {
      if (percents[i] > percents[maxIndex]) maxIndex = i;
    }
    if (percents[maxIndex] != maxPercent) percents[maxIndex] = maxPercent;

    return FlickerSchedule._(masked, List<int>.unmodifiable(percents));
  }

  const FlickerSchedule._(this.seed, this._percents);

  /// Number of levels in one loop.
  static const int levelCount = 16;

  /// Time between two levels, in milliseconds.
  static const int stepMs = 400;

  /// Length of one full loop, in milliseconds.
  static const int loopMs = 6400;

  /// Lowest level, in percent.
  static const int minPercent = 75;

  /// Highest level, in percent.
  static const int maxPercent = 100;

  /// Lowest opacity the schedule can return.
  static const double minOpacity = 0.75;

  /// Highest opacity the schedule can return.
  static const double maxOpacity = 1.0;

  /// Opacity used for the static frame under reduced motion.
  static const double staticOpacity = 1.0;

  /// The seed after masking with 0xFFFFFFFF.
  final int seed;

  final List<int> _percents;

  /// The 16 level opacities, unmodifiable, each a whole percent divided by 100.
  List<double> get levels => List<double>.unmodifiable(<double>[
    for (final int p in _percents) p / 100,
  ]);

  /// Opacity in 0.75..1.0 at [elapsedMs]. Never throws.
  ///
  /// Negative times wrap with Dart's non-negative `%`.
  double opacityAt(int elapsedMs) {
    final int phase = elapsedMs % loopMs;
    final int seg = phase ~/ stepMs;
    final int w = phase - seg * stepMs;
    final int a = _percents[seg];
    final int b = _percents[(seg + 1) % levelCount];
    // Smoothstep numerator over 400^3 = 64000000. At most 63998802.
    final int s = w * w * (1200 - 2 * w);
    // Largest numerator is about 6.4e9, exact on every platform.
    return (a * 64000000 + (b - a) * s) / 6400000000;
  }
}
