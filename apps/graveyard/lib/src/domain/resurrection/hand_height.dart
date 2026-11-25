import '../scene/rise_progress.dart';
import 'play_timing.dart';

/// Pure function from elapsed milliseconds to the hand's height, from 0
/// (hidden) to 1 (fully out).
abstract final class HandHeight {
  /// Returns the hand's height after [elapsedMs] milliseconds of the play.
  ///
  /// The height is 0 for negative input and from
  /// [PlayTiming.handSinkEndMs] on. During the burst
  /// (0 to [PlayTiming.handBurstEndMs]) it rises along [RiseProgress]; during
  /// the sink (up to [PlayTiming.handSinkEndMs]) it falls back along the same
  /// curve. The result is finite and within `[0, 1]`.
  static double at(int elapsedMs) {
    if (elapsedMs < 0 || elapsedMs >= PlayTiming.handSinkEndMs) {
      return 0;
    }
    if (elapsedMs <= PlayTiming.handBurstEndMs) {
      return RiseProgress.at(_rescale(elapsedMs, PlayTiming.handBurstEndMs));
    }
    return 1 -
        RiseProgress.at(
          _rescale(
            elapsedMs - PlayTiming.handBurstEndMs,
            PlayTiming.handSinkEndMs - PlayTiming.handBurstEndMs,
          ),
        );
  }

  /// Maps [ms] within a phase of [spanMs] onto [RiseProgress]'s own domain.
  static int _rescale(int ms, int spanMs) =>
      (ms * RiseProgress.durationMs / spanMs).round();
}
