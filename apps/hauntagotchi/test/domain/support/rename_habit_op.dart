part of 'operation.dart';

/// Renames the habit at [index] to the raw name [name].
final class RenameHabitOp extends HabitOp {
  /// Creates a rename operation.
  const RenameHabitOp(super.index, this.name);

  /// The raw new name, valid or not.
  final String name;
}
