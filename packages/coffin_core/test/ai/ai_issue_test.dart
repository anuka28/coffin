import 'package:coffin_core/src/ai/ai_issue.dart';
import 'package:coffin_core/src/ai/ai_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiIssue.forKind', () {
    test('threw message', () {
      expect(
        AiIssue.forKind(AiIssueKind.threw).message,
        'The AI source threw an error, so the fallback was used.',
      );
    });

    test('timedOut message', () {
      expect(
        AiIssue.forKind(AiIssueKind.timedOut).message,
        'The AI source did not answer in time, so the fallback was used.',
      );
    });

    test('emptyReply message', () {
      expect(
        AiIssue.forKind(AiIssueKind.emptyReply).message,
        'The AI source returned an empty reply, so the fallback was used.',
      );
    });

    test('invalidReply message', () {
      expect(
        AiIssue.forKind(AiIssueKind.invalidReply).message,
        'The AI source returned a reply that was too long, '
        'so the fallback was used.',
      );
    });

    test('keeps the kind', () {
      for (final AiIssueKind kind in AiIssueKind.values) {
        expect(AiIssue.forKind(kind).kind, kind);
      }
    });
  });

  group('AiIssue equality', () {
    const AiIssue base = AiIssue(kind: AiIssueKind.threw, message: 'm');

    test('equal fields give equal values and hashes', () {
      const AiIssue same = AiIssue(kind: AiIssueKind.threw, message: 'm');
      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    test('a different kind is not equal', () {
      const AiIssue other = AiIssue(kind: AiIssueKind.timedOut, message: 'm');
      expect(base == other, isFalse);
      expect(base.hashCode == other.hashCode, isFalse);
    });

    test('a different message is not equal', () {
      const AiIssue other = AiIssue(kind: AiIssueKind.threw, message: 'n');
      expect(base == other, isFalse);
      expect(base.hashCode == other.hashCode, isFalse);
    });

    test('forKind values for one kind are equal', () {
      expect(
        AiIssue.forKind(AiIssueKind.emptyReply),
        AiIssue.forKind(AiIssueKind.emptyReply),
      );
    });

    test('toString shows the kind and the message', () {
      expect(base.toString(), 'AiIssue(kind: threw, message: m)');
    });
  });
}
