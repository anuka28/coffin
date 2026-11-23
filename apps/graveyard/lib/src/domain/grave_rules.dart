import 'calendar_date.dart';
import 'grave_rejection.dart';
import 'manual_grave_check.dart';
import 'name_rules.dart';

/// Rules for graves typed by hand.
abstract final class GraveRules {
  /// Checks a by-hand grave.
  ///
  /// The date arrives as parts so that an impossible date such as 2025-02-30
  /// is rejected and never shifted. Checks run in this order: empty name, name
  /// over 80 code points, date missing, date not real, before 1970-01-01,
  /// after [today]. [today] and 1970-01-01 are accepted.
  static ManualGraveCheck checkManual({
    required String rawName,
    required int? year,
    required int? month,
    required int? day,
    required CalendarDate today,
  }) {
    final name = NameRules.normalize(rawName);
    if (name.isEmpty) {
      return const ManualGraveRejected(GraveRejection.nameEmpty);
    }
    if (NameRules.length(name) > NameRules.maxLength) {
      return const ManualGraveRejected(GraveRejection.nameTooLong);
    }
    if (year == null || month == null || day == null) {
      return const ManualGraveRejected(GraveRejection.dateMissing);
    }
    final date = CalendarDate.tryCreate(year, month, day);
    if (date == null) {
      return const ManualGraveRejected(GraveRejection.dateNotReal);
    }
    if (date.compareTo(CalendarDate.earliest) < 0) {
      return const ManualGraveRejected(GraveRejection.dateTooEarly);
    }
    if (date.compareTo(today) > 0) {
      return const ManualGraveRejected(GraveRejection.dateInFuture);
    }
    return ManualGraveAccepted(name, date);
  }
}
