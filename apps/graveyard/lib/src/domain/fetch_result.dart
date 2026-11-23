import 'fetched_repo.dart';
import 'import_failure.dart';

part 'fetch_failed.dart';
part 'fetch_succeeded.dart';

/// The outcome of fetching a repository: a repository or a failure.
sealed class FetchResult {
  /// Creates a fetch result.
  const FetchResult();
}
