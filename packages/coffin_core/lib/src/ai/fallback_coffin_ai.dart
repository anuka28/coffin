import 'dart:async';

import 'ai_fallback_error.dart';
import 'ai_issue.dart';
import 'ai_issue_kind.dart';
import 'ai_issue_reporter.dart';
import 'ai_reply.dart';
import 'ai_request.dart';
import 'ai_timer_factory.dart';
import 'coffin_ai.dart';
import 'text_rules.dart';

/// A [CoffinAI] that asks [primary] first and falls back to [secondary].
///
/// The secondary answers when the primary throws, does not answer within
/// [timeout], returns empty or whitespace-only text, or returns text longer
/// than the request's `maxLength`. Each call is independent: the class keeps
/// no state, never retries, and has no built-in last-resort line.
///
/// Contract of [ask]:
///
/// * It completes with a reply or with an error. It never throws
///   synchronously.
/// * There is no cancellation. A primary that answers after the timeout is
///   ignored, and a late error from it is handled, so nothing reaches the
///   zone as an unhandled error.
/// * Exact-timeout rule: a primary completion counts only if the wrapper
///   observed it before the timer callback ran. A completion at exactly the
///   timeout counts as a timeout.
/// * The secondary is not given a timeout. Wrap a slow secondary in another
///   [FallbackCoffinAI] to bound it.
/// * A usable primary reply is returned unchanged and nothing is reported.
///   An over-long primary reply is never cut.
/// * For every other primary outcome exactly one [AiIssue] is passed to the
///   reporter, before the secondary is asked. A reporter that throws is
///   ignored. A reporter that returns a future which later fails is not
///   caught here.
/// * When the secondary throws or returns an unusable reply, the future
///   completes with an [AiFallbackError] and no second issue is reported.
final class FallbackCoffinAI implements CoffinAI {
  /// Creates a wrapper around [primary] and [secondary].
  ///
  /// [timeout] is how long the primary may take. [reporter] receives one
  /// issue per fallback and defaults to [discardAiIssues]. [timerFactory]
  /// starts the timeout timer and defaults to `Timer.new`; tests pass a fake
  /// clock.
  ///
  /// Throws [ArgumentError] when [timeout] is zero or negative.
  FallbackCoffinAI({
    required this.primary,
    required this.secondary,
    required this.timeout,
    this._reporter = discardAiIssues,
    AiTimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? Timer.new {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'must be greater than zero',
      );
    }
  }

  /// The source asked first.
  final CoffinAI primary;

  /// The source asked when the primary fails. It has no timeout.
  final CoffinAI secondary;

  /// How long the primary may take before it counts as timed out.
  final Duration timeout;

  final AiIssueReporter _reporter;
  final AiTimerFactory _timerFactory;

  /// Answers [request] with the primary's reply, or with the secondary's
  /// reply after reporting one issue, or with an [AiFallbackError].
  ///
  /// Never throws synchronously and cannot be cancelled. See the class
  /// comment for the exact-timeout rule.
  @override
  Future<AiReply> ask(AiRequest request) async {
    final _Attempt attempt = await _tryPrimary(request);
    final AiReply? reply = attempt.reply;
    if (reply != null) return reply;
    final AiIssueKind kind = attempt.failure!;
    reportAiIssueSafely(_reporter, AiIssue.forKind(kind));
    return _askSecondary(request, kind);
  }

  Future<_Attempt> _tryPrimary(AiRequest request) {
    final Future<AiReply> call;
    try {
      call = primary.ask(request);
    } catch (_) {
      return Future<_Attempt>.value(const _Attempt.failed(AiIssueKind.threw));
    }
    final Completer<_Attempt> settled = Completer<_Attempt>();
    void settle(_Attempt attempt) {
      if (!settled.isCompleted) settled.complete(attempt);
    }

    final Timer timer = _timerFactory(
      timeout,
      () => settle(const _Attempt.failed(AiIssueKind.timedOut)),
    );
    unawaited(
      call.then(
        (AiReply reply) => settle(_classify(reply, request)),
        onError: (Object _, StackTrace _) =>
            settle(const _Attempt.failed(AiIssueKind.threw)),
      ),
    );
    return settled.future.whenComplete(timer.cancel);
  }

  _Attempt _classify(AiReply reply, AiRequest request) {
    final AiIssueKind? bad = _unusable(reply, request);
    return bad == null ? _Attempt.ok(reply) : _Attempt.failed(bad);
  }

  AiIssueKind? _unusable(AiReply reply, AiRequest request) {
    if (TextRules.isBlank(reply.text)) return AiIssueKind.emptyReply;
    if (reply.text.length > request.maxLength) return AiIssueKind.invalidReply;
    return null;
  }

  Future<AiReply> _askSecondary(
    AiRequest request,
    AiIssueKind primaryFailure,
  ) async {
    final AiReply reply;
    try {
      reply = await secondary.ask(request);
    } catch (_) {
      throw AiFallbackError(
        primaryFailure: primaryFailure,
        secondaryFailure: AiIssueKind.threw,
      );
    }
    final AiIssueKind? bad = _unusable(reply, request);
    if (bad != null) {
      throw AiFallbackError(
        primaryFailure: primaryFailure,
        secondaryFailure: bad,
      );
    }
    return reply;
  }
}

/// The result of asking the primary: a usable reply or a failure kind.
final class _Attempt {
  const _Attempt.ok(AiReply this.reply) : failure = null;

  const _Attempt.failed(AiIssueKind this.failure) : reply = null;

  final AiReply? reply;
  final AiIssueKind? failure;
}
