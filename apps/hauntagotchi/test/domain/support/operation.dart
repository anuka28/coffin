part 'add_habit_op.dart';
part 'advance_days_op.dart';
part 'archive_habit_op.dart';
part 'complete_op.dart';
part 'rename_habit_op.dart';
part 'undo_op.dart';

/// One step a test can take on a `Haunting`.
///
/// Habits are picked by [HabitOp.index] into the book's list of all habits
/// (wrapping around), so generated operations never need real ids. The parts
/// are in the same library so the type can be sealed. Interpreted by
/// `applyOp` in `haunt_generators.dart`.
sealed class Operation {
  /// Base constructor for the operations.
  const Operation();
}

/// An operation aimed at one habit, picked by [index].
sealed class HabitOp extends Operation {
  /// Creates an operation aimed at the habit at [index].
  const HabitOp(this.index);

  /// Position in the book's list of all habits. Wraps around the length.
  final int index;
}
