/// Millisecond milestones of the resurrection play, shared by the hand,
/// the rising ghost and the epitaph.
abstract final class PlayTiming {
  /// Total length of the play: the 600 ms hand burst-and-sink leaves room
  /// for the 2200 ms rising reaction (600 + 2200 = 2800).
  static const int playDurationMs = 2800;

  /// End of the hand's burst phase: the hand bursts out in the first 300 ms.
  static const int handBurstEndMs = 300;

  /// End of the hand's sink phase: the hand sinks back during the next
  /// 300 ms and is gone once 600 ms have passed.
  static const int handSinkEndMs = 600;

  /// Start of the rising ghost reaction: it begins when the hand is gone.
  static const int risingGhostStartMs = 600;

  /// Start of the ghost's rise: it lifts off together with the rising
  /// reaction.
  static const int ghostRiseStartMs = 600;

  /// Start of the epitaph fade: [risingGhostStartMs] plus 70 percent of the
  /// 2200 ms rising reaction (600 + 1540), so the text appears once the
  /// ghost is mostly up.
  static const int epitaphFadeStartMs = 2140;

  /// End of the ghost's rise: it settles exactly when the epitaph fade
  /// begins.
  static const int ghostRiseEndMs = epitaphFadeStartMs;

  /// Length of the epitaph fade: 400 ms, inside the 300 to 600 ms range of
  /// the design language.
  static const int epitaphFadeMs = 400;
}
