import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'widget_generators.dart';

// Pure support code: no dart:io, no Flutter widgets. It runs in Chrome.
//
// Only web-safe glados generators are used: `simple`, `combine2`,
// `anyIntBetween` and `anyListBetween`. Every integer stays below 2^53.

/// The special progress values drawn about 20 percent of the time.
final List<double> _specialProgress = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
  0,
  1,
];

/// Any of the seven moods, picked by index 0 to 6 over [GhostMood.values].
/// Shrinks towards `thriving`.
Generator<GhostMood> get anyMood => any.simple<GhostMood>(
  generate: (math.Random random, int size) =>
      GhostMood.values[random.nextInt(GhostMood.values.length)],
  shrink: (GhostMood mood) sync* {
    if (mood.index > 0) {
      yield GhostMood.values[mood.index ~/ 2];
    }
  },
);

/// Progress values from minus 1.5 to 2.5 in steps of 0.001 (integer
/// thousandths divided by 1000), with NaN, infinity, negative infinity, 0 and
/// 1 drawn about 20 percent of the time. Shrinks finite values towards 0.
Generator<double> get anyProgress => any.simple<double>(
  generate: (math.Random random, int size) {
    if (random.nextInt(5) == 0) {
      return _specialProgress[random.nextInt(_specialProgress.length)];
    }
    return (random.nextInt(4001) - 1500) / 1000;
  },
  shrink: (double v) sync* {
    if (v.isFinite) {
      final int thousandths = (v * 1000).round();
      if (thousandths != 0) {
        yield (thousandths ~/ 2) / 1000;
      }
    }
  },
);

/// Chains of 1 to 6 pairs of a mood and a progress value.
Generator<List<(GhostMood, double)>> get anyChain =>
    anyListBetween<(GhostMood, double)>(
      1,
      7,
      any.combine2<GhostMood, double, (GhostMood, double)>(
        anyMood,
        anyProgress,
        (GhostMood mood, double progress) => (mood, progress),
      ),
    );
