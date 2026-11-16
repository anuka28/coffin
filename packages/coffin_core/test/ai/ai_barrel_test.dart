import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_clock.dart';

/// A [CoffinAI] written outside `coffin_core`, using only the barrel.
final class _AppAI implements CoffinAI {
  _AppAI(this._behaviour);

  final Future<AiReply> Function(AiRequest request) _behaviour;

  @override
  Future<AiReply> ask(AiRequest request) => _behaviour(request);
}

AiRequest _request() => AiRequest(
  purpose: AiPurpose.ghostMoodLine,
  facts: <String, Object?>{
    AiFactKeys.ghostName: 'Boo',
    AiFactKeys.streakCount: 3,
    AiFactKeys.daysSinceLastCommit: 214,
    AiFactKeys.projectName: 'Crypt',
  },
  maxLength: 120,
  seed: 7,
);

void main() {
  test('every exported AI name is usable', () async {
    final AiRequest request = _request();
    expect(request.purpose, AiPurpose.ghostMoodLine);
    expect(request.facts[AiFactKeys.ghostName], 'Boo');
    expect(AiPurpose('custom_purpose').id, 'custom_purpose');

    final ReplySource source = ReplySource('my_model');
    expect(source.name, 'my_model');
    final AiReply reply = AiReply(text: 'Boo!', source: source);
    expect(reply.isUsableFor(request), isTrue);

    final AiIssue issue = AiIssue.forKind(AiIssueKind.timedOut);
    expect(issue.kind, AiIssueKind.timedOut);
    expect(issue.message, isNotEmpty);

    final AiReply offline = await const OfflineCoffinAI().ask(request);
    expect(offline.source, ReplySource.offline);
    expect(offline.isUsableFor(request), isTrue);

    final FakeClock clock = FakeClock();
    final AiTimerFactory factory = clock.create;
    final FallbackCoffinAI fallback = FallbackCoffinAI(
      primary: const OfflineCoffinAI(),
      secondary: const OfflineCoffinAI(),
      timeout: const Duration(seconds: 1),
      timerFactory: factory,
    );
    expect((await fallback.ask(request)).source, ReplySource.offline);
    expect(clock.pendingTimers, 0);
  });

  test('an app-defined CoffinAI works as the primary', () async {
    final FakeClock clock = FakeClock();
    final AiRequest request = _request();
    final AiReply mine = AiReply(
      text: 'From my app',
      source: ReplySource('app'),
    );
    final List<AiIssue> issues = <AiIssue>[];
    final FallbackCoffinAI ai = FallbackCoffinAI(
      primary: _AppAI((AiRequest _) async => mine),
      secondary: const OfflineCoffinAI(),
      timeout: const Duration(seconds: 1),
      reporter: issues.add,
      timerFactory: clock.create,
    );

    expect(await ai.ask(request), mine);
    expect(issues, isEmpty);
    expect(clock.pendingTimers, 0);
  });

  test('a throwing primary falls back and reports one threw issue', () async {
    final FakeClock clock = FakeClock();
    final List<AiIssue> issues = <AiIssue>[];
    final AiIssueReporter reporter = issues.add;
    final FallbackCoffinAI ai = FallbackCoffinAI(
      primary: _AppAI((AiRequest _) => throw StateError('boom')),
      secondary: const OfflineCoffinAI(),
      timeout: const Duration(seconds: 1),
      reporter: reporter,
      timerFactory: clock.create,
    );

    final AiReply reply = await ai.ask(_request());

    expect(reply.source, ReplySource.offline);
    expect(issues, hasLength(1));
    expect(issues.single.kind, AiIssueKind.threw);
    discardAiIssues(issues.single);
  });

  test('AiFallbackError can be caught by type', () async {
    final FallbackCoffinAI ai = FallbackCoffinAI(
      primary: _AppAI((AiRequest _) => throw StateError('boom')),
      secondary: _AppAI((AiRequest _) => throw StateError('bang')),
      timeout: const Duration(seconds: 1),
      timerFactory: FakeClock().create,
    );

    Object? caught;
    try {
      await ai.ask(_request());
    } on AiFallbackError catch (e) {
      caught = e;
    }

    expect(caught, isA<AiFallbackError>());
    final AiFallbackError error = caught! as AiFallbackError;
    expect(error.primaryFailure, AiIssueKind.threw);
    expect(error.secondaryFailure, AiIssueKind.threw);
  });
}
