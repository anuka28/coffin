/// Why a habit change was refused.
enum HabitRejection {
  /// The name is empty after trimming.
  nameEmpty,

  /// The name is longer than `NameRules.maxLength`.
  nameTooLong,

  /// Five habits are already active.
  limitReached,

  /// No habit has the given id.
  unknownHabit,

  /// The habit is archived and cannot change.
  habitArchived,

  /// The habit is already completed on that day.
  alreadyCompleted,

  /// The habit is not completed on that day.
  notCompleted,

  /// Only today can be completed or undone.
  notToday,
}
