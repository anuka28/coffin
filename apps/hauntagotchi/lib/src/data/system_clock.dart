import '../domain/clock.dart';

/// The real [Clock]. The only place in the app that reads the system time.
final class SystemClock implements Clock {
  /// Creates a clock that reads the device's local time.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
