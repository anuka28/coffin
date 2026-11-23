import 'calendar_date.dart';
import 'dead_for_unit.dart';

/// How long a project has been dead, as a unit and a count.
final class DeadFor {
  /// Creates a span of [count] [unit]s. [count] is 0 for
  /// [DeadForUnit.today] and 1 or more otherwise.
  const DeadFor(this.unit, this.count);

  /// Works out the span from [dateOfDeath] to [today] using calendar days and
  /// whole calendar months only.
  ///
  /// A date of death on or after [today] gives [DeadForUnit.today].
  factory DeadFor.between(CalendarDate dateOfDeath, CalendarDate today) {
    final days = dateOfDeath.daysUntil(today);
    if (days <= 0) return const DeadFor(DeadForUnit.today, 0);
    final months = dateOfDeath.wholeMonthsUntil(today);
    if (months >= 12) return DeadFor(DeadForUnit.years, months ~/ 12);
    if (months >= 1) return DeadFor(DeadForUnit.months, months);
    if (days >= 7) return DeadFor(DeadForUnit.weeks, days ~/ 7);
    return DeadFor(DeadForUnit.days, days);
  }

  /// The unit of the span.
  final DeadForUnit unit;

  /// The number of [unit]s: 0 for today, otherwise 1 or more.
  final int count;

  /// The display text, such as `Died today` or `Dead for 3 weeks`.
  String get text {
    final name = switch (unit) {
      DeadForUnit.today => null,
      DeadForUnit.days => 'day',
      DeadForUnit.weeks => 'week',
      DeadForUnit.months => 'month',
      DeadForUnit.years => 'year',
    };
    if (name == null) return 'Died today';
    return 'Dead for $count $name${count == 1 ? '' : 's'}';
  }

  @override
  bool operator ==(Object other) =>
      other is DeadFor && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'DeadFor($unit, $count)';
}
