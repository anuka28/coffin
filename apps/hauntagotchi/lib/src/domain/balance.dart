/// Tuning numbers for the ghost's health and the daily ritual.
abstract final class Balance {
  /// The highest Health a ghost can have.
  static const int maxHealth = 100;

  /// The Health a fully completed day adds.
  static const int fullFeed = 20;

  /// The Health an idle or neglected day removes.
  static const int neglectLoss = 15;

  /// The Health a resurrected ghost starts with.
  static const int freshStartHealth = 40;

  /// The number of candles needed to resurrect a ghost.
  static const int candlesNeeded = 2;

  /// The share of habits, in percent, that makes a day qualifying.
  static const int qualifyingPercent = 60;

  /// The name of a new ghost.
  static const String defaultGhostName = 'Wisp';

  /// The Health gained when [c] of [n] habits are completed.
  ///
  /// Returns `fullFeed * c / n` rounded down, and 0 when [n] is not positive.
  static int feed(int n, int c) => n <= 0 ? 0 : (fullFeed * c) ~/ n;
}
