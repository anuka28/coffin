import 'balance.dart';
import 'ghost.dart';
import 'habit_book.dart';
import 'local_day.dart';

/// Settles the ghost's Health for the days that passed since it was last open.
abstract final class CatchUp {
  /// Settles every finished day after `ghost.lastSettledDay` up to yesterday.
  ///
  /// Returns [ghost] unchanged when it is already settled through yesterday
  /// (or the clock moved backward). A dead ghost only advances
  /// `lastSettledDay`. Days are settled in order and the loop stops once
  /// Health reaches 0. The name and resurrection count are kept.
  static Ghost run(Ghost ghost, HabitBook book, LocalDay today) {
    final target = today.previous;
    if (ghost.lastSettledDay.compareTo(target) >= 0) {
      return ghost;
    }
    var health = ghost.health;
    if (health > 0) {
      var d = ghost.lastSettledDay.next;
      while (d.compareTo(target) <= 0 && health > 0) {
        health = settleDay(
          health,
          book.activeCountOn(d),
          book.completedCountOn(d),
        );
        d = d.next;
      }
    }
    return Ghost(
      name: ghost.name,
      health: health,
      lastSettledDay: target,
      resurrectionCount: ghost.resurrectionCount,
    );
  }

  /// The Health after one finished day with [activeCount] active habits of
  /// which [completedCount] were completed.
  ///
  /// No active habit leaves [health] unchanged. No completion removes
  /// [Balance.neglectLoss] (not below 0). Otherwise the day feeds the ghost
  /// (not above [Balance.maxHealth]).
  static int settleDay(int health, int activeCount, int completedCount) {
    if (activeCount == 0) {
      return health;
    }
    if (completedCount == 0) {
      final lowered = health - Balance.neglectLoss;
      return lowered < 0 ? 0 : lowered;
    }
    final raised = health + Balance.feed(activeCount, completedCount);
    return raised > Balance.maxHealth ? Balance.maxHealth : raised;
  }
}
