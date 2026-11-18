part of 'haunt_result.dart';

/// An action that was refused.
final class HauntRejected extends HauntResult {
  /// Creates a result carrying the [reason].
  const HauntRejected(this.reason);

  /// Why the action was refused.
  final HabitRejection reason;
}
