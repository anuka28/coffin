/// The single source of the current time for the domain and controller.
abstract interface class Clock {
  /// The current local date and time.
  DateTime now();
}
