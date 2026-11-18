import 'habit_rejection.dart';
import 'haunting.dart';

part 'haunt_changed.dart';
part 'haunt_rejected.dart';

/// The outcome of a [Haunting] action: `HauntChanged` or `HauntRejected`.
///
/// The two outcomes are parts of this library so the type can be sealed.
sealed class HauntResult {
  /// Base constructor for the two outcomes.
  const HauntResult();
}
