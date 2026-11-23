/// A source of the current moment, injected so tests control time.
abstract interface class Clock {
  /// The current moment in local time.
  DateTime now();
}
