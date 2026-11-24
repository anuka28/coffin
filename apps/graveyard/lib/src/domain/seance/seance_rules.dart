import 'revival_band.dart';
import 'revival_steps.dart';
import 'seance_facts.dart';
import 'seance_result.dart';

/// Pure scoring rules of a séance.
abstract final class SeanceRules {
  /// Computes the score, band and steps for [facts]. Pure, deterministic,
  /// integer arithmetic only, never throws.
  ///
  /// Age gives up to 70 points, stars up to 10, a described or hand-buried
  /// grave +6, an archived repository -25. The sum is clamped to 0..100.
  static SeanceResult evaluate(SeanceFacts facts) {
    final int raw =
        _agePoints(facts.dayCount) +
        _starPoints(facts.stars) +
        (facts.hasDescription || facts.manual ? 6 : 0) -
        (facts.archived ? 25 : 0);
    final int score = raw < 0 ? 0 : (raw > 100 ? 100 : raw);
    return SeanceResult(
      score: score,
      band: RevivalBand.forScore(score),
      steps: RevivalSteps.choose(facts),
    );
  }

  static int _agePoints(int dayCount) {
    if (dayCount <= 30) return 70;
    if (dayCount <= 90) return 66;
    if (dayCount <= 180) return 56;
    if (dayCount <= 365) return 46;
    if (dayCount <= 730) return 34;
    if (dayCount <= 1095) return 24;
    if (dayCount <= 1825) return 14;
    if (dayCount <= 3650) return 6;
    return 0;
  }

  static int _starPoints(int stars) {
    if (stars <= 0) return 0;
    final int bits = (stars + 1).bitLength;
    return bits > 10 ? 10 : bits;
  }
}
