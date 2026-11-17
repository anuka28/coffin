import 'raise_error_kind.dart';

/// What [Raiser.raise] returns. Failures are returned, never thrown.
sealed class RaiseResult {
  const RaiseResult();
}

/// The app was raised.
final class RaiseSuccess extends RaiseResult {
  /// Creates a success listing [createdPaths].
  const RaiseSuccess(this.createdPaths);

  /// Every directory and file created under `apps/`, in creation order. The
  /// edited root `pubspec.yaml` is not listed.
  final List<String> createdPaths;
}

/// The raise did not happen.
final class RaiseFailure extends RaiseResult {
  /// Creates a failure of [kind] with a plain [message].
  const RaiseFailure(this.kind, this.message, {this.suggestion});

  /// The category of the failure.
  final RaiseErrorKind kind;

  /// A plain explanation, without spooky copy.
  final String message;

  /// A valid alternative name, when one could be derived.
  final String? suggestion;
}
