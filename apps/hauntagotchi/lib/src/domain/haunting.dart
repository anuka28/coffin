import 'balance.dart';
import 'catch_up.dart';
import 'ghost.dart';
import 'ghost_state.dart';
import 'ghost_state_rules.dart';
import 'habit_book.dart';
import 'habit_result.dart';
import 'haunt_result.dart';
import 'local_day.dart';
import 'recent_history.dart';
import 'resurrection_ritual.dart';
import 'ritual_progress.dart';
import 'streak.dart';

/// The whole game state: the habits, the ghost and today's date.
///
/// Immutable. Every action returns a new [Haunting] or a rejection.
final class Haunting {
  /// Creates a haunting from its parts, without settling any day.
  const Haunting({
    required this.book,
    required this.ghost,
    required this.today,
  });

  /// Opens a haunting for [today].
  ///
  /// Uses [Ghost.fresh] when [ghost] is null, then settles missed days.
  factory Haunting.open({
    required HabitBook book,
    Ghost? ghost,
    required LocalDay today,
  }) {
    return Haunting(
      book: book,
      ghost: ghost ?? Ghost.fresh(today),
      today: today,
    ).syncTo(today);
  }

  /// The habits.
  final HabitBook book;

  /// The ghost, with Health settled through yesterday.
  final Ghost ghost;

  /// The current day.
  final LocalDay today;

  /// Moves to [newToday], settles missed days, then checks the ritual.
  ///
  /// Returns this when nothing changes.
  Haunting syncTo(LocalDay newToday) {
    final Ghost settled = CatchUp.run(ghost, book, newToday);
    final Ghost next =
        ResurrectionRitual.apply(settled, book, newToday) ?? settled;
    if (next == ghost && newToday == today) {
      return this;
    }
    return Haunting(book: book, ghost: next, today: newToday);
  }

  /// The Health shown today: 0 when dead, else settled Health plus today's feed.
  int get liveHealth {
    if (ghost.isDead) {
      return 0;
    }
    final int sum =
        ghost.health +
        Balance.feed(book.activeCountOn(today), book.completedCountOn(today));
    return sum > Balance.maxHealth ? Balance.maxHealth : sum;
  }

  /// The recent history used to derive [state].
  ///
  /// Idle days are 0 when any habit is completed today. Otherwise they count
  /// back from yesterday over days with active habits and no completion,
  /// capped at 7.
  RecentHistory get history {
    if (book.anyCompletedOn(today)) {
      return const RecentHistory(idleDays: 0);
    }
    int idle = 0;
    LocalDay d = today;
    while (idle < 7 && _hasPrevious(d)) {
      d = d.previous;
      if (book.activeCountOn(d) > 0 && book.completedCountOn(d) == 0) {
        idle++;
      } else {
        break;
      }
    }
    return RecentHistory(idleDays: idle);
  }

  /// The ghost's state.
  GhostState get state => GhostStateRules.derive(liveHealth, history);

  /// The current streak.
  int get streak => Streak.compute(book, today);

  /// The resurrection ritual progress, or null when no habit is active.
  RitualProgress? get ritual => ResurrectionRitual.progress(book, today);

  /// Adds a habit named [rawName].
  HauntResult addHabit(String rawName) =>
      _apply(book.add(rawName, today: today));

  /// Renames the habit [id] to [rawName].
  HauntResult renameHabit(String id, String rawName) =>
      _apply(book.rename(id, rawName));

  /// Archives the habit [id].
  HauntResult archiveHabit(String id) => _apply(book.archive(id, today: today));

  /// Completes the habit [id] for today.
  HauntResult complete(String id) =>
      _apply(book.complete(id, today, today: today));

  /// Undoes today's completion of the habit [id].
  HauntResult undo(String id) => _apply(book.undo(id, today, today: today));

  HauntResult _apply(HabitResult result) {
    switch (result) {
      case HabitRejected(:final reason):
        return HauntRejected(reason);
      case HabitChanged(book: final newBook):
        final Ghost? revived = ResurrectionRitual.apply(ghost, newBook, today);
        return HauntChanged(
          Haunting(book: newBook, ghost: revived ?? ghost, today: today),
          resurrected: revived != null,
        );
    }
  }

  static bool _hasPrevious(LocalDay d) =>
      d.year > 1 || d.month > 1 || d.day > 1;
}
