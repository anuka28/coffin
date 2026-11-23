part of 'fetch_result.dart';

/// The repository could not be fetched.
final class FetchFailed extends FetchResult {
  /// Creates a failed result.
  const FetchFailed(this.failure);

  /// Why the fetch failed.
  final ImportFailure failure;

  @override
  bool operator ==(Object other) =>
      other is FetchFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
