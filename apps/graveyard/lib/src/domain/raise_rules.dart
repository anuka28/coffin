import 'calendar_date.dart';
import 'grave.dart';

/// Pure rules for raising a [Grave] from the dead and laying it to rest.
abstract final class RaiseRules {
  /// Raises [grave] on [today].
  ///
  /// Returns the same grave when it is already Risen, so the first date stays.
  static Grave raise(Grave grave, CalendarDate today) =>
      grave.risenOn != null ? grave : grave.copyWithRisenOn(today);

  /// Lays [grave] to rest by clearing its risen date.
  ///
  /// Returns the same grave when it is not Risen.
  static Grave layToRest(Grave grave) =>
      grave.risenOn == null ? grave : grave.copyWithRisenOn(null);
}
