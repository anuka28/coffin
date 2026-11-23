import '../domain/calendar_date.dart';
import '../domain/fetch_result.dart';
import '../domain/repo_ref.dart';

/// Fetches a public GitHub repository for the import flow.
abstract interface class GitHubClient {
  /// Fetches [ref]; [today] is the local calendar date used to clamp the date
  /// of death.
  ///
  /// Never throws. Every error arrives as a failed [FetchResult].
  Future<FetchResult> fetch(RepoRef ref, {required CalendarDate today});
}
