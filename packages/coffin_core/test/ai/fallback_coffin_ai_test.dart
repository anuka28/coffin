import 'dart:async';

import 'package:coffin_core/src/ai/ai_fallback_error.dart';
import 'package:coffin_core/src/ai/ai_issue.dart';
import 'package:coffin_core/src/ai/ai_issue_kind.dart';
import 'package:coffin_core/src/ai/ai_issue_reporter.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/coffin_ai.dart';
import 'package:coffin_core/src/ai/offline_coffin_ai.dart';
import 'package:coffin_core/src/ai/fallback_coffin_ai.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_clock.dart';
import 'support/scripted_ai.dart';

const Duration _timeout = Duration(seconds: 30);

Future<void> _pump() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.value();
  }
}

AiRequest _request() =>
    AiRequest(purpose: AiPurpose.ghostMoodLine, maxLength: 40);

void main() {
  group('FallbackCoffinAI smoke', () {
    late FakeClock clock;
    late List<AiIssue> issues;
    final ReplySource fallbackSource = ReplySource('fallback');

    FallbackCoffinAI build(
      ScriptedCoffinAI primary,
      ScriptedCoffinAI secondary,
    ) => FallbackCoffinAI(
      primary: primary,
      secondary: secondary,
      timeout: _timeout,
      reporter: issues.add,
      timerFactory: clock.create,
    );

    ScriptedCoffinAI secondaryOk() => ScriptedCoffinAI(<ScriptedOutcome>[
      ScriptedOutcome.reply('from secondary', source: fallbackSource),
    ]);

    setUp(() {
      clock = FakeClock();
      issues = <AiIssue>[];
    });

    test('rejects a zero or negative timeout', () {
      for (final Duration d in <Duration>[
        Duration.zero,
        const Duration(seconds: -1),
      ]) {
        expect(
          () => FallbackCoffinAI(
            primary: secondaryOk(),
            secondary: secondaryOk(),
            timeout: d,
          ),
          throwsArgumentError,
        );
      }
    });

    test(
      'success returns the primary reply unchanged and reports nothing',
      () async {
        final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
          ScriptedOutcome.reply('hello'),
        ]);
        final ScriptedCoffinAI secondary = secondaryOk();
        final AiReply reply = await build(primary, secondary).ask(_request());
        expect(reply.text, 'hello');
        expect(reply.source, scriptedSource);
        expect(issues, isEmpty);
        expect(secondary.callCount, 0);
        expect(clock.pendingTimers, 0);
      },
    );

    test('synchronous throw reports threw and creates no timer', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.syncThrow(),
      ]);
      final Future<AiReply> future = build(
        primary,
        secondaryOk(),
      ).ask(_request());
      expect(clock.pendingTimers, 0);
      expect((await future).text, 'from secondary');
      expect(issues, <AiIssue>[AiIssue.forKind(AiIssueKind.threw)]);
    });

    test('asynchronous error reports threw', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.asyncError(),
      ]);
      final AiReply reply = await build(primary, secondaryOk()).ask(_request());
      expect(reply.source, fallbackSource);
      expect(issues, <AiIssue>[AiIssue.forKind(AiIssueKind.threw)]);
      expect(clock.pendingTimers, 0);
    });

    test('timeout reports timedOut and uses the secondary', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.never(),
      ]);
      final Future<AiReply> future = build(
        primary,
        secondaryOk(),
      ).ask(_request());
      await _pump();
      expect(clock.pendingTimers, 1);
      clock.advance(_timeout);
      expect((await future).text, 'from secondary');
      expect(issues, <AiIssue>[AiIssue.forKind(AiIssueKind.timedOut)]);
      expect(clock.pendingTimers, 0);
    });

    test('empty reply reports emptyReply', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.blank('   '),
      ]);
      final AiReply reply = await build(primary, secondaryOk()).ask(_request());
      expect(reply.source, fallbackSource);
      expect(issues, <AiIssue>[AiIssue.forKind(AiIssueKind.emptyReply)]);
    });

    test('overlong reply reports invalidReply and is not cut', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.overlong(),
      ]);
      final AiReply reply = await build(primary, secondaryOk()).ask(_request());
      expect(reply.text, 'from secondary');
      expect(issues, <AiIssue>[AiIssue.forKind(AiIssueKind.invalidReply)]);
    });

    test(
      'failing secondary completes with AiFallbackError, one issue',
      () async {
        final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
          ScriptedOutcome.asyncError(),
        ]);
        final ScriptedCoffinAI secondary = ScriptedCoffinAI(<ScriptedOutcome>[
          ScriptedOutcome.syncThrow(),
        ]);
        await expectLater(
          build(primary, secondary).ask(_request()),
          throwsA(
            isA<AiFallbackError>()
                .having(
                  (AiFallbackError e) => e.primaryFailure,
                  'primaryFailure',
                  AiIssueKind.threw,
                )
                .having(
                  (AiFallbackError e) => e.secondaryFailure,
                  'secondaryFailure',
                  AiIssueKind.threw,
                ),
          ),
        );
        expect(issues, hasLength(1));
      },
    );
  });

  _wrapperExamples();
  _boundaryAndLateCompletion();
}

/// Runs [body] inside `runZonedGuarded`, waits for it, pumps microtasks and
/// returns every error that reached the zone as unhandled.
Future<List<Object>> _unhandledErrorsFrom(Future<void> Function() body) async {
  final List<Object> unhandled = <Object>[];
  final Completer<void> done = Completer<void>();
  runZonedGuarded(() {
    body().then(done.complete, onError: done.completeError);
  }, (Object error, StackTrace _) => unhandled.add(error));
  await done.future;
  await _pump();
  return unhandled;
}

void _boundaryAndLateCompletion() {
  const Duration oneMs = Duration(milliseconds: 1);
  final ReplySource secondarySource = ReplySource('fallback');

  late FakeClock clock;
  late List<AiIssue> issues;
  late Completer<AiReply> late_;
  late AiReply primaryReply;
  late FallbackCoffinAI ai;
  late ScriptedCoffinAI secondary;

  setUp(() {
    clock = FakeClock();
    issues = <AiIssue>[];
    late_ = Completer<AiReply>();
    primaryReply = AiReply(text: 'primary says', source: scriptedSource);
    secondary = ScriptedCoffinAI(<ScriptedOutcome>[
      ScriptedOutcome.reply('secondary says', source: secondarySource),
    ]);
    ai = FallbackCoffinAI(
      primary: ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.lateReply(late_),
      ]),
      secondary: secondary,
      timeout: _timeout,
      reporter: issues.add,
      timerFactory: clock.create,
    );
  });

  FallbackCoffinAI wrapperFor(Completer<AiReply> completer) => FallbackCoffinAI(
    primary: ScriptedCoffinAI(<ScriptedOutcome>[
      ScriptedOutcome.lateReply(completer),
    ]),
    secondary: secondary,
    timeout: _timeout,
    reporter: issues.add,
    timerFactory: clock.create,
  );

  group('FallbackCoffinAI exactly-at-timeout rule', () {
    test('four rows with a 30 s timeout run in milliseconds', () async {
      final Stopwatch watch = Stopwatch()..start();

      // Row 1: completes at timeout - 1 ms, microtasks pumped, then the
      // clock reaches the timeout. Success.
      final Future<AiReply> row1 = ai.ask(_request());
      expect(clock.pendingTimers, 1);
      clock.advance(_timeout - oneMs);
      late_.complete(primaryReply);
      await _pump();
      clock.advance(oneMs);
      final AiReply reply1 = await row1;
      expect(reply1, same(primaryReply), reason: 'row 1');
      expect(reply1.source, scriptedSource, reason: 'row 1');
      expect(issues, isEmpty, reason: 'row 1');
      expect(secondary.callCount, 0, reason: 'row 1');
      expect(clock.pendingTimers, 0, reason: 'row 1');

      // Rows 2 to 4 each need a fresh wrapper, primary and secondary.
      Future<AiReply> startRow(Completer<AiReply> completer) {
        issues.clear();
        secondary = ScriptedCoffinAI(<ScriptedOutcome>[
          ScriptedOutcome.reply('secondary says', source: secondarySource),
        ]);
        return FallbackCoffinAI(
          primary: ScriptedCoffinAI(<ScriptedOutcome>[
            ScriptedOutcome.lateReply(completer),
          ]),
          secondary: secondary,
          timeout: _timeout,
          reporter: issues.add,
          timerFactory: clock.create,
        ).ask(_request());
      }

      void expectTimedOut(AiReply reply, String row) {
        expect(reply.source, secondarySource, reason: row);
        expect(reply.text, 'secondary says', reason: row);
        expect(issues, hasLength(1), reason: row);
        expect(issues.single.kind, AiIssueKind.timedOut, reason: row);
        expect(secondary.callCount, 1, reason: row);
        expect(clock.pendingTimers, 0, reason: row);
      }

      // Row 2: the clock reaches exactly the timeout, then the primary
      // completes. Timed out.
      final Completer<AiReply> c2 = Completer<AiReply>();
      final Future<AiReply> row2 = startRow(c2);
      clock.advance(_timeout);
      c2.complete(primaryReply);
      await _pump();
      expectTimedOut(await row2, 'row 2');

      // Row 3: the primary completes and, in the same synchronous block, the
      // clock reaches the timeout. No pump in between. Timed out.
      final Completer<AiReply> c3 = Completer<AiReply>();
      final Future<AiReply> row3 = startRow(c3);
      c3.complete(primaryReply);
      clock.advance(_timeout);
      await _pump();
      expectTimedOut(await row3, 'row 3');

      // Row 4: the clock passes the timeout by 1 ms, then the primary
      // completes. Timed out.
      final Completer<AiReply> c4 = Completer<AiReply>();
      final Future<AiReply> row4 = startRow(c4);
      clock.advance(_timeout + oneMs);
      c4.complete(primaryReply);
      await _pump();
      expectTimedOut(await row4, 'row 4');

      watch.stop();
      // ignore: avoid_print
      print('boundary test wall time: ${watch.elapsedMilliseconds} ms');
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('FallbackCoffinAI late completion', () {
    test(
      'control: an unhandled error in the guarded zone is captured',
      () async {
        final List<Object> unhandled = await _unhandledErrorsFrom(() async {
          // No listener is attached, so the zone must see this error.
          Future<void>.error(StateError('control'));
          await _pump();
        });
        expect(unhandled, hasLength(1));
        expect(unhandled.single, isA<StateError>());
      },
    );

    test('a late value is ignored and raises no zone error', () async {
      late AiReply first;
      final List<Object> unhandled = await _unhandledErrorsFrom(() async {
        // Created inside the guarded zone: an unhandled error is reported to
        // the zone that owns the future.
        final Completer<AiReply> lateCompleter = Completer<AiReply>();
        final Future<AiReply> future = wrapperFor(lateCompleter)
            .ask(_request());
        await _pump();
        clock.advance(_timeout);
        first = await future;
        lateCompleter.complete(primaryReply);
        await _pump();
      });
      expect(unhandled, isEmpty);
      expect(first.source, secondarySource);
      expect(first.text, 'secondary says');
      expect(issues, hasLength(1));
      expect(issues.single.kind, AiIssueKind.timedOut);
      expect(secondary.callCount, 1);
      expect(clock.pendingTimers, 0);
    });

    test('a late error is ignored and raises no zone error', () async {
      late AiReply first;
      final List<Object> unhandled = await _unhandledErrorsFrom(() async {
        final Completer<AiReply> lateCompleter = Completer<AiReply>();
        final Future<AiReply> future = wrapperFor(lateCompleter)
            .ask(_request());
        await _pump();
        clock.advance(_timeout);
        first = await future;
        lateCompleter.completeError(StateError('late failure'));
        await _pump();
      });
      expect(unhandled, isEmpty);
      expect(first.source, secondarySource);
      expect(first.text, 'secondary says');
      expect(issues, hasLength(1));
      expect(issues.single.kind, AiIssueKind.timedOut);
      expect(secondary.callCount, 1);
      expect(clock.pendingTimers, 0);
    });
  });
}

/// Returns the same fixed reply for every call.
final class _FixedAI implements CoffinAI {
  _FixedAI(this.reply);

  final AiReply reply;

  @override
  Future<AiReply> ask(AiRequest request) => Future<AiReply>.value(reply);
}

const Map<AiIssueKind, String> _messages = <AiIssueKind, String>{
  AiIssueKind.threw: 'The AI source threw an error, so the fallback was used.',
  AiIssueKind.timedOut:
      'The AI source did not answer in time, so the fallback was used.',
  AiIssueKind.emptyReply:
      'The AI source returned an empty reply, so the fallback was used.',
  AiIssueKind.invalidReply:
      'The AI source returned a reply that was too long, '
      'so the fallback was used.',
};

AiRequest _factRequest() => AiRequest(
  purpose: AiPurpose.ghostMoodLine,
  facts: <String, Object?>{'ghostName': 'ZZFACT1', 'streakCount': 7},
  maxLength: 80,
);

void _wrapperExamples() {
  late FakeClock clock;
  late List<AiIssue> issues;
  const OfflineCoffinAI offline = OfflineCoffinAI();

  setUp(() {
    clock = FakeClock();
    issues = <AiIssue>[];
  });

  FallbackCoffinAI build(
    CoffinAI primary, {
    CoffinAI secondary = offline,
    AiIssueReporter? reporter,
  }) => FallbackCoffinAI(
    primary: primary,
    secondary: secondary,
    timeout: _timeout,
    reporter: reporter ?? issues.add,
    timerFactory: clock.create,
  );

  ScriptedCoffinAI scripted(ScriptedOutcome o) =>
      ScriptedCoffinAI(<ScriptedOutcome>[o]);

  group('FallbackCoffinAI outcomes with an offline secondary', () {
    test('success returns the same reply object and reports nothing', () async {
      final AiReply original = AiReply(
        text: 'primary line',
        source: scriptedSource,
      );
      final ScriptedCoffinAI primary = scripted(
        ScriptedOutcome.reply(original.text),
      );
      final AiRequest request = _request();
      final List<AiIssue> snapshot = <AiIssue>[];
      final Future<AiReply> future = build(primary).ask(request);
      final AiReply reply = await future;
      snapshot.addAll(issues);
      expect(reply.text, original.text);
      expect(reply.source, scriptedSource);
      expect(snapshot, isEmpty);
      expect(primary.callCount, 1);
      expect(primary.requests.single, same(request));
    });

    test('success passes the very same reply object through', () async {
      final AiReply original = AiReply(
        text: 'same object',
        source: scriptedSource,
      );
      final AiReply reply = await build(
        _FixedAI(original),
        secondary: _FixedAI(AiReply(text: 'no', source: ReplySource.offline)),
      ).ask(_request());
      expect(reply, same(original));
      expect(issues, isEmpty);
    });

    test('success does not call the secondary', () async {
      final ScriptedCoffinAI secondary = ScriptedCoffinAI(<ScriptedOutcome>[]);
      await build(
        scripted(ScriptedOutcome.reply('fine')),
        secondary: secondary,
      ).ask(_request());
      expect(secondary.callCount, 0);
    });

    final Map<String, ({ScriptedOutcome Function() outcome, AiIssueKind kind})>
    failures =
        <String, ({ScriptedOutcome Function() outcome, AiIssueKind kind})>{
          'synchronous throw': (
            outcome: ScriptedOutcome.syncThrow,
            kind: AiIssueKind.threw,
          ),
          'asynchronous error': (
            outcome: ScriptedOutcome.asyncError,
            kind: AiIssueKind.threw,
          ),
          'never-completing': (
            outcome: ScriptedOutcome.never,
            kind: AiIssueKind.timedOut,
          ),
          'empty reply': (
            outcome: ScriptedOutcome.blank,
            kind: AiIssueKind.emptyReply,
          ),
          'whitespace-only reply': (
            outcome: () => ScriptedOutcome.blank(' \t\n\u00A0\u3000 '),
            kind: AiIssueKind.emptyReply,
          ),
          'overlong reply': (
            outcome: ScriptedOutcome.overlong,
            kind: AiIssueKind.invalidReply,
          ),
        };

    for (final MapEntry<
          String,
          ({ScriptedOutcome Function() outcome, AiIssueKind kind})
        >
        entry
        in failures.entries) {
      test('${entry.key}: reports ${entry.value.kind.name} before completion, '
          'returns the offline reply', () async {
        final AiRequest request = _factRequest();
        final ScriptedCoffinAI primary = scripted(entry.value.outcome());
        final List<AiIssue> atCompletion = <AiIssue>[];
        final Future<AiReply> future = build(primary).ask(request);
        final Future<void> observed = future.then((AiReply r) {
          atCompletion.addAll(issues);
        });
        if (entry.value.kind == AiIssueKind.timedOut) {
          await _pump();
          expect(issues, isEmpty);
          clock.advance(_timeout);
        }
        final AiReply reply = await future;
        await observed;
        final AiReply expected = await offline.ask(request);
        expect(reply.text, expected.text);
        expect(reply.source, ReplySource.offline);
        expect(atCompletion, hasLength(1));
        expect(atCompletion.single.kind, entry.value.kind);
        expect(atCompletion.single.message, _messages[entry.value.kind]);
        expect(issues, hasLength(1));
        expect(primary.callCount, 1);
        expect(primary.requests.single, same(request));
      });
    }

    test('an overlong reply is not truncated into a success', () async {
      final AiReply reply = await build(scripted(ScriptedOutcome.overlong()))
          .ask(_request());
      expect(reply.source, ReplySource.offline);
      expect(reply.text.length, lessThanOrEqualTo(40));
      expect(issues.single.kind, AiIssueKind.invalidReply);
    });

    test('no timer is pending after success, failure and timeout', () async {
      await build(scripted(ScriptedOutcome.reply('ok'))).ask(_request());
      expect(clock.pendingTimers, 0);
      await build(scripted(ScriptedOutcome.asyncError())).ask(_request());
      expect(clock.pendingTimers, 0);
      await build(scripted(ScriptedOutcome.overlong())).ask(_request());
      expect(clock.pendingTimers, 0);
      final Future<AiReply> future = build(scripted(ScriptedOutcome.never()))
          .ask(_request());
      await _pump();
      expect(clock.pendingTimers, 1);
      clock.advance(_timeout);
      await future;
      expect(clock.pendingTimers, 0);
    });

    test('a non-offline source passes through unchanged', () async {
      final AiReply remote = AiReply(
        text: 'from afar',
        source: ReplySource('remote'),
      );
      final AiReply reply = await build(_FixedAI(remote)).ask(_request());
      expect(reply, same(remote));
      expect(reply.source, ReplySource('remote'));
      expect(issues, isEmpty);
    });
  });

  group('FallbackCoffinAI construction and reporter', () {
    test('zero and negative timeouts throw ArgumentError', () {
      for (final Duration d in <Duration>[
        Duration.zero,
        const Duration(microseconds: -1),
        const Duration(minutes: -5),
      ]) {
        expect(
          () => FallbackCoffinAI(
            primary: offline,
            secondary: offline,
            timeout: d,
          ),
          throwsArgumentError,
        );
      }
    });

    test('the default reporter works when none is supplied', () async {
      final FallbackCoffinAI ai = FallbackCoffinAI(
        primary: scripted(ScriptedOutcome.asyncError()),
        secondary: offline,
        timeout: _timeout,
        timerFactory: clock.create,
      );
      final AiReply reply = await ai.ask(_request());
      expect(reply.source, ReplySource.offline);
    });

    test('works with the real timer factory', () async {
      final FallbackCoffinAI ai = FallbackCoffinAI(
        primary: scripted(ScriptedOutcome.reply('real timer')),
        secondary: offline,
        timeout: _timeout,
      );
      expect((await ai.ask(_request())).text, 'real timer');
    });

    test('a throwing reporter does not stop the secondary reply', () async {
      int calls = 0;
      final AiReply reply = await build(
        scripted(ScriptedOutcome.syncThrow()),
        reporter: (AiIssue issue) {
          calls++;
          throw StateError('reporter broke');
        },
      ).ask(_request());
      expect(calls, 1);
      expect(reply.source, ReplySource.offline);
    });
  });

  group('FallbackCoffinAI failing secondary', () {
    final Map<String, ({CoffinAI Function() secondary, AiIssueKind kind})>
    secondaries = <String, ({CoffinAI Function() secondary, AiIssueKind kind})>{
      'throws': (
        secondary: () => ScriptedSecondary.throws(synchronously: true),
        kind: AiIssueKind.threw,
      ),
      'fails asynchronously': (
        secondary: ScriptedSecondary.throws,
        kind: AiIssueKind.threw,
      ),
      'returns an empty reply': (
        secondary: ScriptedSecondary.empty,
        kind: AiIssueKind.emptyReply,
      ),
      'returns an overlong reply': (
        secondary: ScriptedSecondary.overlong,
        kind: AiIssueKind.invalidReply,
      ),
    };

    for (final MapEntry<
          String,
          ({CoffinAI Function() secondary, AiIssueKind kind})
        >
        entry
        in secondaries.entries) {
      test('secondary ${entry.key}: AiFallbackError, one issue', () async {
        final Future<AiReply> future = build(
          scripted(ScriptedOutcome.asyncError()),
          secondary: entry.value.secondary(),
        ).ask(_request());
        await expectLater(
          future,
          throwsA(
            isA<AiFallbackError>()
                .having(
                  (AiFallbackError e) => e.primaryFailure,
                  'primaryFailure',
                  AiIssueKind.threw,
                )
                .having(
                  (AiFallbackError e) => e.secondaryFailure,
                  'secondaryFailure',
                  entry.value.kind,
                ),
          ),
        );
        expect(issues, hasLength(1));
        expect(issues.single.kind, AiIssueKind.threw);
      });
    }

    test('primary timeout then failing secondary keeps both kinds', () async {
      final Future<AiReply> future = build(
        scripted(ScriptedOutcome.never()),
        secondary: ScriptedSecondary.empty(),
      ).ask(_request());
      final Future<void> check = expectLater(
        future,
        throwsA(
          isA<AiFallbackError>()
              .having(
                (AiFallbackError e) => e.primaryFailure,
                'primaryFailure',
                AiIssueKind.timedOut,
              )
              .having(
                (AiFallbackError e) => e.secondaryFailure,
                'secondaryFailure',
                AiIssueKind.emptyReply,
              ),
        ),
      );
      await _pump();
      clock.advance(_timeout);
      await check;
      expect(issues, hasLength(1));
    });

    test('toString holds no reply text and no fact value', () async {
      final AiRequest request = AiRequest(
        purpose: AiPurpose.ghostMoodLine,
        facts: <String, Object?>{
          'ghostName': 'ZZFACT1',
          'projectName': 'ZZFACT2',
          'streakCount': 31337,
        },
        maxLength: 40,
      );
      final AiFallbackError error =
          await build(
                _FixedAI(
                  AiReply(text: 'ZZMARK1${'p' * 60}', source: scriptedSource),
                ),
                secondary: _FixedAI(
                  AiReply(
                    text: 'ZZMARK2${'s' * 60}',
                    source: ReplySource.offline,
                  ),
                ),
              )
              .ask(request)
              .then<AiFallbackError>(
                (AiReply r) => fail('expected an error'),
                onError: (Object e) => e as AiFallbackError,
              );
      final String text = error.toString();
      for (final String marker in <String>[
        'ZZMARK1',
        'ZZMARK2',
        'ZZFACT1',
        'ZZFACT2',
        '31337',
      ]) {
        expect(text, isNot(contains(marker)));
      }
      expect(error.primaryFailure, AiIssueKind.invalidReply);
      expect(error.secondaryFailure, AiIssueKind.invalidReply);
      expect(issues, hasLength(1));
    });
  });

  group('FallbackCoffinAI overlapping calls', () {
    for (final bool reverse in <bool>[false, true]) {
      test('completing ${reverse ? 'second first' : 'first first'}: '
          'each call has its own result and issue', () async {
        final Completer<AiReply> a = Completer<AiReply>();
        final Completer<AiReply> b = Completer<AiReply>();
        final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
          ScriptedOutcome.lateError(a),
          ScriptedOutcome.lateReply(b),
        ]);
        final FallbackCoffinAI ai = build(primary);
        final AiRequest requestA = _factRequest();
        final AiRequest requestB = _request();
        final Future<AiReply> futureA = ai.ask(requestA);
        final Future<AiReply> futureB = ai.ask(requestB);
        expect(clock.pendingTimers, 2);
        final AiReply usable = AiReply(text: 'for b', source: scriptedSource);
        void completeA() => a.completeError(StateError('late'));
        void completeB() => b.complete(usable);
        if (reverse) {
          completeB();
          completeA();
        } else {
          completeA();
          completeB();
        }
        final AiReply replyA = await futureA;
        final AiReply replyB = await futureB;
        expect(replyA.text, (await offline.ask(requestA)).text);
        expect(replyA.source, ReplySource.offline);
        expect(replyB, same(usable));
        expect(issues, hasLength(1));
        expect(issues.single.kind, AiIssueKind.threw);
        expect(clock.pendingTimers, 0);
      });

      test('two failing calls (${reverse ? 'reverse' : 'forward'} order) '
          'report two different issues', () async {
        final Completer<AiReply> a = Completer<AiReply>();
        final Completer<AiReply> b = Completer<AiReply>();
        final FallbackCoffinAI ai = build(
          ScriptedCoffinAI(<ScriptedOutcome>[
            ScriptedOutcome.lateReply(a),
            ScriptedOutcome.lateReply(b),
          ]),
        );
        final Future<AiReply> futureA = ai.ask(_request());
        final Future<AiReply> futureB = ai.ask(_request());
        final AiReply blank = AiReply(text: '  ', source: scriptedSource);
        final AiReply long = AiReply(text: 'y' * 41, source: scriptedSource);
        if (reverse) {
          b.complete(long);
          a.complete(blank);
        } else {
          a.complete(blank);
          b.complete(long);
        }
        expect((await futureA).source, ReplySource.offline);
        expect((await futureB).source, ReplySource.offline);
        expect(
          issues.map((AiIssue i) => i.kind).toList()..sort(
            (AiIssueKind x, AiIssueKind y) => x.index.compareTo(y.index),
          ),
          <AiIssueKind>[
            AiIssueKind.emptyReply,
            AiIssueKind.invalidReply,
          ]..sort((AiIssueKind x, AiIssueKind y) => x.index.compareTo(y.index)),
        );
        expect(
          issues.first.kind,
          reverse ? AiIssueKind.invalidReply : AiIssueKind.emptyReply,
        );
      });
    }
  });

  group('FallbackCoffinAI composition and state', () {
    test('as a primary: a working inner wrapper answers', () async {
      final List<AiIssue> inner = <AiIssue>[];
      final FallbackCoffinAI innerAi = build(
        scripted(ScriptedOutcome.asyncError()),
        reporter: inner.add,
      );
      final AiRequest request = _request();
      final AiReply reply = await build(innerAi).ask(request);
      expect(reply.text, (await offline.ask(request)).text);
      expect(inner.single.kind, AiIssueKind.threw);
      expect(issues, isEmpty);
    });

    test('as a primary: a failing inner wrapper counts as threw', () async {
      final FallbackCoffinAI innerAi = build(
        scripted(ScriptedOutcome.asyncError()),
        secondary: ScriptedSecondary.empty(),
        reporter: (AiIssue _) {},
      );
      final AiRequest request = _request();
      final AiReply reply = await build(innerAi).ask(request);
      expect(reply.source, ReplySource.offline);
      expect(reply.text, (await offline.ask(request)).text);
      expect(issues.single.kind, AiIssueKind.threw);
    });

    test('as a secondary: a working inner wrapper answers', () async {
      final FallbackCoffinAI innerAi = build(
        scripted(ScriptedOutcome.reply('inner primary')),
        reporter: (AiIssue _) {},
      );
      final AiReply reply = await build(
        scripted(ScriptedOutcome.syncThrow()),
        secondary: innerAi,
      ).ask(_request());
      expect(reply.text, 'inner primary');
      expect(issues.single.kind, AiIssueKind.threw);
    });

    test(
      'as a secondary: a failing inner wrapper gives AiFallbackError',
      () async {
        final FallbackCoffinAI innerAi = build(
          scripted(ScriptedOutcome.asyncError()),
          secondary: ScriptedSecondary.throws(),
          reporter: (AiIssue _) {},
        );
        await expectLater(
          build(
            scripted(ScriptedOutcome.overlong()),
            secondary: innerAi,
          ).ask(_request()),
          throwsA(
            isA<AiFallbackError>()
                .having(
                  (AiFallbackError e) => e.primaryFailure,
                  'primaryFailure',
                  AiIssueKind.invalidReply,
                )
                .having(
                  (AiFallbackError e) => e.secondaryFailure,
                  'secondaryFailure',
                  AiIssueKind.threw,
                ),
          ),
        );
        expect(issues, hasLength(1));
      },
    );

    test('a failed call does not change the next call', () async {
      final ScriptedCoffinAI primary = ScriptedCoffinAI(<ScriptedOutcome>[
        ScriptedOutcome.never(),
        ScriptedOutcome.reply('second'),
        ScriptedOutcome.asyncError(),
      ]);
      final FallbackCoffinAI ai = build(primary);
      final Future<AiReply> first = ai.ask(_request());
      await _pump();
      clock.advance(_timeout);
      expect((await first).source, ReplySource.offline);
      final AiReply second = await ai.ask(_request());
      expect(second.text, 'second');
      expect(second.source, scriptedSource);
      expect(issues, hasLength(1));
      expect((await ai.ask(_request())).source, ReplySource.offline);
      expect(issues.map((AiIssue i) => i.kind), <AiIssueKind>[
        AiIssueKind.timedOut,
        AiIssueKind.threw,
      ]);
      expect(clock.pendingTimers, 0);
    });
  });
}
