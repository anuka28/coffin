part of 'operation.dart';

/// Undoes today's completion of the habit at [index].
final class UndoOp extends HabitOp {
  /// Creates an undo operation.
  const UndoOp(super.index);
}
