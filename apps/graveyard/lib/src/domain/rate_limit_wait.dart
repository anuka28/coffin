import 'dart:math' as math;

/// Turns a rate-limit reset moment into a wait in whole minutes.
abstract final class RateLimitWait {
  /// Minutes from [now] until [resetAt], rounded up and never below 1.
  static int minutes({required DateTime resetAt, required DateTime now}) {
    final ms = resetAt.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    return math.max(1, (ms + 59999) ~/ 60000);
  }
}
