import 'ai_issue.dart';

/// Receives every [AiIssue]. Exceptions it throws are swallowed.
typedef AiIssueReporter = void Function(AiIssue issue);

/// The default reporter: drops every issue.
void discardAiIssues(AiIssue issue) {}

/// Calls [reporter] with [issue] and swallows anything it throws.
///
/// Internal helper, not exported. A faulty reporter must never change the
/// reply an app receives.
void reportAiIssueSafely(AiIssueReporter reporter, AiIssue issue) {
  try {
    reporter(issue);
  } catch (_) {
    // A broken reporter must not affect the AI call.
  }
}
