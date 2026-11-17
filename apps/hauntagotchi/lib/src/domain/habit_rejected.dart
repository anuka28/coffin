part of 'habit_result.dart';

/// A habit change that was refused.
final class HabitRejected extends HabitResult {
  /// Creates a result carrying the [reason].
  const HabitRejected(this.reason);

  /// Why the change was refused.
  final HabitRejection reason;
}
