import 'habit.dart';
import 'habit_rejection.dart';
import 'habit_result.dart';
import 'local_day.dart';
import 'name_rules.dart';

/// An immutable list of habits, in creation order, with the habit rules.
final class HabitBook {
  /// Creates a book holding a copy of [habits].
  HabitBook(Iterable<Habit> habits)
    : _habits = List<Habit>.unmodifiable(habits);

  /// Builds a book from stored habits. When more than [maxActive] are active,
  /// keeps the oldest ones (by created day, then id) and archives the rest
  /// on [today].
  factory HabitBook.restore(Iterable<Habit> stored, {required LocalDay today}) {
    final List<Habit> habits = stored.toList();
    final List<Habit> active = habits.where((Habit h) => h.isActive).toList()
      ..sort(_byAge);
    if (active.length <= maxActive) {
      return HabitBook(habits);
    }
    final Set<String> overflow = active
        .skip(maxActive)
        .map((Habit h) => h.id)
        .toSet();
    return HabitBook(
      habits.map((Habit h) {
        if (!overflow.contains(h.id)) {
          return h;
        }
        final LocalDay day = h.createdDay.compareTo(today) > 0
            ? h.createdDay
            : today;
        return h.copyWith(archivedDay: day);
      }),
    );
  }

  /// The most active habits allowed.
  static const int maxActive = 5;

  /// The number of active habits that is suggested at least.
  static const int suggestedMin = 3;

  final List<Habit> _habits;

  static int _byAge(Habit a, Habit b) {
    final int c = a.createdDay.compareTo(b.createdDay);
    if (c != 0) {
      return c;
    }
    return a.id.length != b.id.length
        ? a.id.length.compareTo(b.id.length)
        : a.id.compareTo(b.id);
  }

  /// Every habit, archived ones included (unmodifiable).
  List<Habit> get all => _habits;

  /// The habits that are not archived.
  List<Habit> get active =>
      List<Habit>.unmodifiable(_habits.where((Habit h) => h.isActive));

  /// How many habits are active.
  int get activeCount => _habits.where((Habit h) => h.isActive).length;

  /// Whether another habit may be added.
  bool get canAdd => activeCount < maxActive;

  /// How many more habits reach [suggestedMin] (0 when already there).
  int get missingToSuggested {
    final int missing = suggestedMin - activeCount;
    return missing > 0 ? missing : 0;
  }

  /// Adds a habit named [rawName] (trimmed), created on [today].
  HabitResult add(String rawName, {required LocalDay today}) {
    final HabitRejection? bad = _nameProblem(rawName);
    if (bad != null) {
      return HabitRejected(bad);
    }
    if (!canAdd) {
      return const HabitRejected(HabitRejection.limitReached);
    }
    final Set<String> used = _habits.map((Habit h) => h.id).toSet();
    int n = 1;
    while (used.contains('h$n')) {
      n++;
    }
    return HabitChanged(
      HabitBook(<Habit>[
        ..._habits,
        Habit(id: 'h$n', name: NameRules.normalize(rawName), createdDay: today),
      ]),
    );
  }

  /// Renames an active habit.
  HabitResult rename(String id, String rawName) {
    final HabitRejection? bad = _nameProblem(rawName);
    if (bad != null) {
      return HabitRejected(bad);
    }
    final Habit? habit = _find(id);
    final HabitRejection? state = _stateProblem(habit);
    if (state != null) {
      return HabitRejected(state);
    }
    return HabitChanged(
      _replace(habit!, habit.copyWith(name: NameRules.normalize(rawName))),
    );
  }

  /// Archives an active habit on [today]. Its completions are kept.
  HabitResult archive(String id, {required LocalDay today}) {
    final Habit? habit = _find(id);
    final HabitRejection? state = _stateProblem(habit);
    if (state != null) {
      return HabitRejected(state);
    }
    return HabitChanged(_replace(habit!, habit.copyWith(archivedDay: today)));
  }

  /// Marks the habit completed on [day], which must be [today].
  HabitResult complete(String id, LocalDay day, {required LocalDay today}) {
    final HabitRejection? bad = _checkToggle(id, day, today);
    if (bad != null) {
      return HabitRejected(bad);
    }
    final Habit habit = _find(id)!;
    if (habit.isCompletedOn(day)) {
      return const HabitRejected(HabitRejection.alreadyCompleted);
    }
    return HabitChanged(
      _replace(
        habit,
        habit.copyWith(completedDays: {...habit.completedDays, day}),
      ),
    );
  }

  /// Removes the completion on [day], which must be [today].
  HabitResult undo(String id, LocalDay day, {required LocalDay today}) {
    final HabitRejection? bad = _checkToggle(id, day, today);
    if (bad != null) {
      return HabitRejected(bad);
    }
    final Habit habit = _find(id)!;
    if (!habit.isCompletedOn(day)) {
      return const HabitRejected(HabitRejection.notCompleted);
    }
    return HabitChanged(
      _replace(
        habit,
        habit.copyWith(
          completedDays: habit.completedDays
              .where((LocalDay d) => d != day)
              .toSet(),
        ),
      ),
    );
  }

  /// How many habits were active on [d].
  int activeCountOn(LocalDay d) =>
      _habits.where((Habit h) => h.isActiveOn(d)).length;

  /// How many habits active on [d] were completed on [d].
  int completedCountOn(LocalDay d) =>
      _habits.where((Habit h) => h.isActiveOn(d) && h.isCompletedOn(d)).length;

  /// Whether any habit, archived or not, was completed on [d].
  bool anyCompletedOn(LocalDay d) =>
      _habits.any((Habit h) => h.isCompletedOn(d));

  HabitRejection? _checkToggle(String id, LocalDay day, LocalDay today) {
    if (day != today) {
      return HabitRejection.notToday;
    }
    return _stateProblem(_find(id));
  }

  HabitRejection? _nameProblem(String raw) {
    if (NameRules.violation(raw) == null) {
      return null;
    }
    return raw.trim().isEmpty
        ? HabitRejection.nameEmpty
        : HabitRejection.nameTooLong;
  }

  HabitRejection? _stateProblem(Habit? habit) {
    if (habit == null) {
      return HabitRejection.unknownHabit;
    }
    return habit.isActive ? null : HabitRejection.habitArchived;
  }

  Habit? _find(String id) {
    for (final Habit h in _habits) {
      if (h.id == id) {
        return h;
      }
    }
    return null;
  }

  HabitBook _replace(Habit old, Habit next) =>
      HabitBook(_habits.map((Habit h) => identical(h, old) ? next : h));
}
