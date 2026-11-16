/// Easing shared by the ghost bob and the fog drift.
abstract final class PingPong {
  /// Eased back-and-forth value in [0, 1] for a phase inside one period.
  ///
  /// The value rises from 0 at phase 0 to 1 at half the period and falls
  /// back to 0 at the end. Precondition: 1 <= [periodMs] <= 90000 and
  /// 0 <= [phaseMs] < [periodMs]. Inputs outside that range are not
  /// clamped, and the result is then unspecified.
  ///
  /// This is `smoothstep(n / P)` with the polynomial scaled to integers, so
  /// all intermediates stay below 2^53 and there is a single division.
  static double at(int phaseMs, int periodMs) {
    var n = 2 * phaseMs;
    if (n > periodMs) {
      n = 2 * periodMs - n;
    }
    return n * n * (3 * periodMs - 2 * n) / (periodMs * periodMs * periodMs);
  }
}
