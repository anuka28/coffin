import 'revival_band.dart';
import 'revival_step_kind.dart';

/// The outcome of a séance, without the verdict line.
final class SeanceResult {
  /// Creates a result.
  const SeanceResult({
    required this.score,
    required this.band,
    required this.steps,
  });

  /// The revival score, 0 to 100.
  final int score;

  /// The band of [score].
  final RevivalBand band;

  /// The three revival step kinds, in display order.
  final List<RevivalStepKind> steps;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SeanceResult ||
        other.score != score ||
        other.band != band ||
        other.steps.length != steps.length) {
      return false;
    }
    for (int i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(score, band, Object.hashAll(steps));

  @override
  String toString() =>
      'SeanceResult(score: $score, band: $band, steps: $steps)';
}
