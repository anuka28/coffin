import '../domain/clock.dart';

/// The production [Clock]: reads the device's local time.
///
/// This is the only place in the app that calls `DateTime.now()`.
final class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
