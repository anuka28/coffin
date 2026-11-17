import '../raise/raise_error_kind.dart';
import 'raise_plan.dart';

/// The result of planning: a [PlanReady] plan or a [PlanRejected] refusal.
sealed class RaiseOutcome {
  const RaiseOutcome();
}

/// Every check passed; [plan] can be written.
final class PlanReady extends RaiseOutcome {
  /// Creates an outcome holding [plan].
  const PlanReady(this.plan);

  /// The plan to write.
  final RaisePlan plan;
}

/// A check failed. Nothing has been written.
final class PlanRejected extends RaiseOutcome {
  /// Creates a refusal of [kind] with a plain [message].
  const PlanRejected(this.kind, this.message, {this.suggestion});

  /// The category of the failure.
  final RaiseErrorKind kind;

  /// A plain explanation. For template problems it names the file.
  final String message;

  /// A valid alternative name, when one could be derived.
  final String? suggestion;
}
