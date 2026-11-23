import '../domain/ghost_state.dart';
import '../domain/habit_rejection.dart';

/// Every user-facing string of the Hauntagotchi home screen, in one file so
/// the copy can be reviewed in one sitting.
///
/// The tone is short, spooky and kind. No string blames the user.
abstract final class HauntCopy {
  /// The state word shown for [state].
  static String stateWord(GhostState state) => switch (state) {
    GhostState.dead => 'Gone, for now',
    GhostState.fading => 'Fading',
    GhostState.hungry => 'Hungry',
    GhostState.content => 'Content',
    GhostState.thriving => 'Thriving',
  };

  /// A gentle nudge naming how many more habits are suggested.
  ///
  /// [missing] is the number of habits short of the suggested minimum.
  static String nudge(int missing) {
    final habits = missing == 1 ? 'habit' : 'habits';
    return 'Add $missing more $habits and your ghost will have plenty to '
        'feast on.';
  }

  /// Shown while progress is not being saved to the device.
  static const String memoryNotice =
      'The crypt is closed to visitors right now, so progress will not be '
      'saved when you leave.';

  /// Shown when a change could not be written. Pairs with a Retry button.
  static const String saveError =
      "The spirits couldn't write that down. Your progress is safe here for "
      'now.';

  /// Shown when saved data could not be read. Pairs with a Retry button.
  static const String loadError =
      "The crypt door is stuck and we couldn't reach your ghost. Try again?";

  /// Label of the Retry buttons.
  static const String retry = 'Retry';

  /// The ritual explanation for a dead ghost.
  ///
  /// [ghostName] is the ghost's name and [needed] the number of habits to
  /// finish today.
  static String ritualText(String ghostName, int needed) {
    final candles = needed == 1 ? 'candle' : 'candles';
    final habits = needed == 1 ? 'habit' : 'habits';
    return '$ghostName is gone, for now. Light $needed $candles today by '
        'finishing $needed $habits and $ghostName drifts back.';
  }

  /// Ritual progress such as `1 of 2 candles lit`.
  static String candleProgress(int done, int needed) {
    final candles = needed == 1 ? 'candle' : 'candles';
    return '$done of $needed $candles lit';
  }

  /// Shown on the dead panel when no habit is active.
  static const String addHabitToBeginRitual =
      'Add a habit to begin the ritual.';

  /// The resurrection count line.
  static String resurrectionCount(int count) {
    if (count == 0) return 'Never lost to the mist.';
    final times = count == 1 ? 'time' : 'times';
    return 'Brought back $count $times.';
  }

  /// Shown once after the ritual completes.
  static String welcomeBack(String ghostName) =>
      'Welcome back, $ghostName. The candles worked.';

  /// Label of the button that dismisses the welcome-back message.
  static const String welcomeBackDismiss = 'Thanks';

  /// Title of the empty state when there is no active habit.
  static const String emptyTitle = 'The crypt is quiet';

  /// Invitation shown when there is no active habit.
  static const String emptyInvitation =
      'Add your first habit and give your ghost something to look forward to.';

  /// Heading of the short "how it works" block in the empty state.
  static const String howItWorksTitle = 'How it works';

  /// The three plain lines that explain the game to a first-time visitor.
  static const List<String> howItWorksLines = <String>[
    'Tick a habit each day and your ghost glows.',
    'Skip a day and it fades a little.',
    'Even a ghost that fades away can come back with a small ritual.',
  ];

  /// Label of the add-habit button.
  static const String addHabit = 'Add a habit';

  /// Reason shown when the habit limit is reached.
  static const String addLimitReason =
      'Five habits is a full crypt. Archive one to make room.';

  /// The reason shown for a refused habit change.
  static String rejectionReason(HabitRejection rejection) =>
      switch (rejection) {
        HabitRejection.nameEmpty => 'Give your habit a name first.',
        HabitRejection.nameTooLong =>
          'That name is a bit long. Try a shorter one.',
        HabitRejection.limitReached => addLimitReason,
        HabitRejection.unknownHabit =>
          'That habit has drifted off. Pull down to refresh.',
        HabitRejection.habitArchived => 'That habit is resting in the archive.',
        HabitRejection.alreadyCompleted => 'Already done for today. Nice.',
        HabitRejection.notCompleted => "That one isn't ticked yet.",
        HabitRejection.notToday => 'Only today can be changed.',
      };
}
