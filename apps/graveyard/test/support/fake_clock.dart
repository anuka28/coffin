import 'package:graveyard/src/domain/clock.dart';

/// A [Clock] whose local time is set by the test.
class FakeClock implements Clock {
  /// Creates a clock that starts at [current].
  FakeClock(this.current);

  /// The moment [now] returns. Tests may assign a new value at any time.
  DateTime current;

  /// Sets the moment [now] returns.
  void set(DateTime value) => current = value;

  @override
  DateTime now() => current;
}
