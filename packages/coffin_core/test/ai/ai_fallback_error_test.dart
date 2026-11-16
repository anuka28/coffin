import 'package:coffin_core/src/ai/ai_fallback_error.dart';
import 'package:coffin_core/src/ai/ai_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carries the two kinds and is an Exception', () {
    const AiFallbackError error = AiFallbackError(
      primaryFailure: AiIssueKind.timedOut,
      secondaryFailure: AiIssueKind.emptyReply,
    );
    expect(error.primaryFailure, AiIssueKind.timedOut);
    expect(error.secondaryFailure, AiIssueKind.emptyReply);
    expect(error, isA<Exception>());
  });

  test('toString is fixed text plus the two kind names', () {
    const AiFallbackError error = AiFallbackError(
      primaryFailure: AiIssueKind.threw,
      secondaryFailure: AiIssueKind.invalidReply,
    );
    expect(
      error.toString(),
      'AiFallbackError: both AI sources failed '
      '(primary: threw, secondary: invalidReply)',
    );
  });

  test('toString varies only with the kinds', () {
    for (final AiIssueKind p in AiIssueKind.values) {
      for (final AiIssueKind s in AiIssueKind.values) {
        expect(
          AiFallbackError(primaryFailure: p, secondaryFailure: s).toString(),
          'AiFallbackError: both AI sources failed '
          '(primary: ${p.name}, secondary: ${s.name})',
        );
      }
    }
  });
}
