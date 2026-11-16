import 'package:coffin_core/src/ai/ai_issue.dart';
import 'package:coffin_core/src/ai/ai_issue_kind.dart';
import 'package:coffin_core/src/ai/ai_issue_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AiIssue issue = AiIssue.forKind(AiIssueKind.threw);

  test('discardAiIssues drops the issue and returns normally', () {
    expect(() => discardAiIssues(issue), returnsNormally);
  });

  test('reportAiIssueSafely passes the issue to the reporter', () {
    final List<AiIssue> seen = <AiIssue>[];
    reportAiIssueSafely(seen.add, issue);
    expect(seen, <AiIssue>[issue]);
  });

  test('a throwing reporter is swallowed and later calls still work', () {
    int calls = 0;
    void flaky(AiIssue i) {
      calls++;
      if (calls == 1) throw StateError('boom');
    }

    expect(() => reportAiIssueSafely(flaky, issue), returnsNormally);
    expect(() => reportAiIssueSafely(flaky, issue), returnsNormally);
    expect(calls, 2);

    final List<AiIssue> seen = <AiIssue>[];
    reportAiIssueSafely(seen.add, issue);
    expect(seen, hasLength(1));
  });

  test('a reporter that throws a non-Exception object is swallowed', () {
    void thrower(AiIssue i) => throw 'plain string';
    expect(() => reportAiIssueSafely(thrower, issue), returnsNormally);
  });
}
