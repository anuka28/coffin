part of 'operation.dart';

/// Adds a habit with the raw name [name], valid or not.
final class AddHabitOp extends Operation {
  /// Creates an add operation for [name].
  const AddHabitOp(this.name);

  /// The raw name, before normalizing.
  final String name;
}
