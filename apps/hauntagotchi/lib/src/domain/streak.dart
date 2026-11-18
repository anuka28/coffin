import 'habit_book.dart';
import 'local_day.dart';

/// The run of consecutive days with at least one completed habit.
///
/// The streak is computed from the book each time and never stored.
abstract final class Streak {
  /// Returns the length of the current streak as of [today].
  ///
  /// Every habit counts, archived ones included. When any habit was completed
  /// on [today], the run ends today. Otherwise, when any habit was completed
  /// yesterday, the run ends yesterday. Otherwise the streak is 0. A day with
  /// no completion ends the run.
  static int compute(HabitBook book, LocalDay today) {
    LocalDay? day;
    if (book.anyCompletedOn(today)) {
      day = today;
    } else if (_hasPrevious(today) && book.anyCompletedOn(today.previous)) {
      day = today.previous;
    }
    int count = 0;
    while (day != null && book.anyCompletedOn(day)) {
      count++;
      day = _hasPrevious(day) ? day.previous : null;
    }
    return count;
  }

  static bool _hasPrevious(LocalDay d) =>
      d.year > 1 || d.month > 1 || d.day > 1;
}
