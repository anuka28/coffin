import 'balance.dart';
import 'ghost.dart';
import 'habit.dart';
import 'habit_book.dart';
import 'local_day.dart';
import 'ritual_progress.dart';

/// The ritual that brings a dead ghost back by completing habits.
abstract final class ResurrectionRitual {
  /// The ritual progress for [today].
  ///
  /// Returns null when no habit is active. Otherwise the ritual needs
  /// `min(Balance.candlesNeeded, activeCount)` active habits completed on
  /// [today].
  static RitualProgress? progress(HabitBook book, LocalDay today) {
    final int activeCount = book.activeCount;
    if (activeCount == 0) {
      return null;
    }
    final int done = book.active
        .where((Habit h) => h.isCompletedOn(today))
        .length;
    final int needed = activeCount < Balance.candlesNeeded
        ? activeCount
        : Balance.candlesNeeded;
    return RitualProgress(done: done, needed: needed);
  }

  /// The revived ghost, or null when [ghost] is alive or the ritual is not
  /// complete.
  ///
  /// The revived ghost keeps its name, has [Balance.freshStartHealth], is
  /// settled through yesterday, and has one more resurrection.
  static Ghost? apply(Ghost ghost, HabitBook book, LocalDay today) {
    if (!ghost.isDead) {
      return null;
    }
    final RitualProgress? p = progress(book, today);
    if (p == null || !p.isComplete) {
      return null;
    }
    return Ghost(
      name: ghost.name,
      health: Balance.freshStartHealth,
      lastSettledDay: today.previous,
      resurrectionCount: ghost.resurrectionCount + 1,
    );
  }
}
