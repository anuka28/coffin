/// How the ghost looks and feels, ordered from worst to best.
enum GhostState {
  /// Health is 0.
  dead,

  /// Health 1 to 24.
  fading,

  /// Health 25 to 49, or capped here by three idle days.
  hungry,

  /// Health 50 to 79, or capped here by one idle day.
  content,

  /// Health 80 to 100.
  thriving,
}
