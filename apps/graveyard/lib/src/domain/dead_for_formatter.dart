import 'calendar_date.dart';
import 'dead_for.dart';

/// Formats how long a project has been dead.
abstract final class DeadForFormatter {
  /// The dead-for text from [dateOfDeath] to [today], such as `Died today`
  /// or `Dead for 1 month`.
  static String format(CalendarDate dateOfDeath, CalendarDate today) =>
      DeadFor.between(dateOfDeath, today).text;
}
