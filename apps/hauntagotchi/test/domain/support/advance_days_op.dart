part of 'operation.dart';

/// Moves today forward by [days] calendar days and settles the missed days.
final class AdvanceDaysOp extends Operation {
  /// Creates an advance operation. [days] is 0 or more.
  const AdvanceDaysOp(this.days);

  /// How many days to move forward.
  final int days;
}
