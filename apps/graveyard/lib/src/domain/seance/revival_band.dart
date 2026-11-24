/// The word band of a revival score.
enum RevivalBand {
  /// Scores 0 to 39.
  restless,

  /// Scores 40 to 69.
  stirring,

  /// Scores 70 to 100.
  readyToRise;

  /// Maps a score to its band. The score is clamped to 0..100 first, so this
  /// never throws.
  static RevivalBand forScore(int score) {
    final int s = score < 0 ? 0 : (score > 100 ? 100 : score);
    if (s <= 39) return RevivalBand.restless;
    if (s <= 69) return RevivalBand.stirring;
    return RevivalBand.readyToRise;
  }
}
