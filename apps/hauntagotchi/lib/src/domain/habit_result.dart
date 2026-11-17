import 'habit_book.dart';
import 'habit_rejection.dart';

part 'habit_changed.dart';
part 'habit_rejected.dart';

/// The outcome of a habit change: `HabitChanged` or `HabitRejected`.
///
/// The two outcomes are parts of this library so the type can be sealed.
sealed class HabitResult {
  /// Base constructor for the two outcomes.
  const HabitResult();
}
