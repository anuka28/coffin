part of 'fetch_result.dart';

/// The repository was fetched and understood.
final class FetchSucceeded extends FetchResult {
  /// Creates a successful result.
  const FetchSucceeded(this.repo);

  /// The fetched repository.
  final FetchedRepo repo;

  @override
  bool operator ==(Object other) =>
      other is FetchSucceeded && other.repo == repo;

  @override
  int get hashCode => repo.hashCode;
}
