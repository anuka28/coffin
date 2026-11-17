part of 'habit_result.dart';

/// A habit change that was applied.
final class HabitChanged extends HabitResult {
  /// Creates a result carrying the updated [book].
  const HabitChanged(this.book);

  /// The book after the change.
  final HabitBook book;
}
