/// The feeling a ghost shows.
///
/// There are five steady moods (`thriving`, `content`, `hungry`, `fading`
/// and `dead`). A steady mood is held until it is changed.
///
/// There are two reaction moods (`fed` and `rising`). A reaction mood plays
/// once and then holds its final pose.
enum GhostMood {
  /// Steady mood: bright, bobbing and full of life.
  thriving,

  /// Steady mood: calm and comfortable.
  content,

  /// Steady mood: a little droopy and in need of a snack.
  hungry,

  /// Steady mood: pale, sinking and losing its glow.
  fading,

  /// Steady mood: gone, still and dim.
  dead,

  /// Reaction mood: a happy pop after a meal, played once.
  fed,

  /// Reaction mood: a rise from the grave, played once.
  rising,
}
