/// What the last few days looked like, as far as the ghost's mood goes.
final class RecentHistory {
  /// Creates a history with [idleDays] days in a row without a completion.
  const RecentHistory({required this.idleDays});

  /// The number of most recent days in a row with no completed habit.
  final int idleDays;
}
