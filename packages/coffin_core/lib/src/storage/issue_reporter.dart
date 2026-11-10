import 'storage_issue.dart';

/// Receives every [StorageIssue]. Exceptions it throws are swallowed.
typedef IssueReporter = void Function(StorageIssue issue);

/// The default reporter: drops every issue.
void discardIssues(StorageIssue issue) {}

/// Calls [reporter] with [issue] and swallows anything it throws.
///
/// Used by repositories and the opener so a faulty reporter can never break
/// a read or an open.
void reportSafely(IssueReporter reporter, StorageIssue issue) {
  try {
    reporter(issue);
  } catch (_) {
    // A broken reporter must not affect storage.
  }
}
