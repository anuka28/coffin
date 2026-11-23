import 'calendar_date.dart';
import 'grave_rejection.dart';

part 'manual_grave_accepted.dart';
part 'manual_grave_rejected.dart';

/// The outcome of checking a by-hand grave: accepted or rejected.
sealed class ManualGraveCheck {
  /// Creates a check result.
  const ManualGraveCheck();
}
