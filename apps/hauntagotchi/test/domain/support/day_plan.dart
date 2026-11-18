/// One day of effort: [n] active habits, [c] of them completed.
final class DayPlan {
  /// Creates a plan. [n] is 1 to 5 and [c] is 0 to [n].
  const DayPlan(this.n, this.c);

  /// Active habits that day.
  final int n;

  /// Completed habits that day.
  final int c;

  /// Whether the day counts as steady effort (at least 60% done).
  bool get qualifies => 5 * c >= 3 * n;

  @override
  bool operator ==(Object other) =>
      other is DayPlan && other.n == n && other.c == c;

  @override
  int get hashCode => Object.hash(n, c);

  @override
  String toString() => 'DayPlan($c of $n)';
}
