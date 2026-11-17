import 'package:hauntagotchi/src/domain/clock.dart';

/// A [Clock] whose time is controlled by the test.
final class FakeClock implements Clock {
  /// Creates a clock that starts at [time].
  FakeClock(this.time);

  /// The time returned by [now]. Assign to jump to another moment.
  DateTime time;

  @override
  DateTime now() => time;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) {
    time = time.add(duration);
  }
}
