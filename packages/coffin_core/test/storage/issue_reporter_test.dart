import 'package:coffin_core/src/storage/issue_reporter.dart';
import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const issue = StorageIssue(
    kind: StorageIssueKind.corruptRecord,
    key: 'a',
    message: 'm',
  );

  group('issue reporter', () {
    test('discardIssues drops the issue without throwing', () {
      expect(() => discardIssues(issue), returnsNormally);
    });

    test('the default reporter discards through reportSafely', () {
      expect(() => reportSafely(discardIssues, issue), returnsNormally);
    });

    test('reportSafely delivers the issue', () {
      final received = <StorageIssue>[];
      reportSafely(received.add, issue);
      expect(received, [issue]);
    });

    test('a throwing reporter is swallowed and later calls still work', () {
      var calls = 0;
      final received = <StorageIssue>[];
      void flaky(StorageIssue i) {
        calls++;
        if (calls == 1) throw StateError('boom');
        received.add(i);
      }

      expect(() => reportSafely(flaky, issue), returnsNormally);
      reportSafely(flaky, issue);
      expect(calls, 2);
      expect(received, [issue]);
    });

    test('non-Exception throwables are swallowed too', () {
      void bad(StorageIssue i) => throw 'just a string';
      expect(() => reportSafely(bad, issue), returnsNormally);
    });
  });
}
