import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

/// One recorded call to `FakeGitHubClient.fetch`.
final class GitHubCall {
  /// Creates a record of a call for [ref] made with [today].
  const GitHubCall(this.ref, this.today);

  /// The repository that was requested.
  final RepoRef ref;

  /// The local calendar date passed to the call.
  final CalendarDate today;
}
