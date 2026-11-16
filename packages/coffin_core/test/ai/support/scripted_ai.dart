import 'dart:async';

import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/coffin_ai.dart';
import 'package:coffin_core/src/ai/reply_source.dart';

/// One scripted answer of a [ScriptedCoffinAI].
final class ScriptedOutcome {
  ScriptedOutcome._(
    this._kind, {
    this.text,
    this.source,
    this.completer,
    this.error,
  });

  /// A usable reply with [text] and [source] (default source `scripted`).
  factory ScriptedOutcome.reply(String text, {ReplySource? source}) =>
      ScriptedOutcome._(_Kind.reply, text: text, source: source);

  /// `ask` throws [error] synchronously.
  factory ScriptedOutcome.syncThrow([
    Object error = const _ScriptedFailure(),
  ]) => ScriptedOutcome._(_Kind.syncThrow, error: error);

  /// `ask` returns a future that already failed with [error].
  factory ScriptedOutcome.asyncError([
    Object error = const _ScriptedFailure(),
  ]) => ScriptedOutcome._(_Kind.asyncError, error: error);

  /// `ask` returns a future that never completes.
  factory ScriptedOutcome.never() => ScriptedOutcome._(_Kind.never);

  /// `ask` returns the future of [completer]. The test completes it later
  /// with a reply.
  factory ScriptedOutcome.lateReply(Completer<AiReply> completer) =>
      ScriptedOutcome._(_Kind.late, completer: completer);

  /// `ask` returns the future of [completer]. The test fails it later with
  /// `completeError`.
  factory ScriptedOutcome.lateError(Completer<AiReply> completer) =>
      ScriptedOutcome._(_Kind.late, completer: completer);

  /// A reply that is empty or whitespace only (default: the empty string).
  factory ScriptedOutcome.blank([String text = '']) =>
      ScriptedOutcome._(_Kind.reply, text: text);

  /// A reply one code unit longer than the request's `maxLength`.
  factory ScriptedOutcome.overlong({ReplySource? source}) =>
      ScriptedOutcome._(_Kind.overlong, source: source);

  final _Kind _kind;

  /// Reply text, for reply and blank outcomes.
  final String? text;

  /// Reply source; `null` means the default `scripted` source.
  final ReplySource? source;

  /// The completer behind a late outcome.
  final Completer<AiReply>? completer;

  /// The error thrown or delivered by the throw and error outcomes.
  final Object? error;
}

enum _Kind { reply, syncThrow, asyncError, never, late, overlong }

final class _ScriptedFailure implements Exception {
  const _ScriptedFailure();

  @override
  String toString() => 'scripted failure';
}

/// The source used when an outcome names none.
final ReplySource scriptedSource = ReplySource('scripted');

AiReply _replyFor(ScriptedOutcome outcome, AiRequest request) {
  if (outcome._kind == _Kind.overlong) {
    return AiReply(
      text: 'x' * (request.maxLength + 1),
      source: outcome.source ?? scriptedSource,
    );
  }
  return AiReply(
    text: outcome.text ?? '',
    source: outcome.source ?? scriptedSource,
  );
}

/// A primary [CoffinAI] driven by a list of outcomes, one per call.
///
/// It counts calls and records every request object. A call beyond the end of
/// the list throws a [StateError], so a test that scripts too little fails
/// loudly.
final class ScriptedCoffinAI implements CoffinAI {
  /// Creates a primary that answers call `i` with `outcomes[i]`.
  ScriptedCoffinAI(List<ScriptedOutcome> outcomes)
    : _outcomes = List<ScriptedOutcome>.unmodifiable(outcomes);

  final List<ScriptedOutcome> _outcomes;
  final List<AiRequest> _requests = <AiRequest>[];

  /// How many times `ask` was called.
  int get callCount => _requests.length;

  /// The request objects received, in call order (the same instances).
  List<AiRequest> get requests => List<AiRequest>.unmodifiable(_requests);

  @override
  Future<AiReply> ask(AiRequest request) {
    final int index = _requests.length;
    _requests.add(request);
    if (index >= _outcomes.length) {
      throw StateError('ScriptedCoffinAI: no outcome for call ${index + 1}');
    }
    final ScriptedOutcome outcome = _outcomes[index];
    switch (outcome._kind) {
      case _Kind.syncThrow:
        throw outcome.error!;
      case _Kind.asyncError:
        return Future<AiReply>.error(outcome.error!);
      case _Kind.never:
        return Completer<AiReply>().future;
      case _Kind.late:
        return outcome.completer!.future;
      case _Kind.reply:
      case _Kind.overlong:
        return Future<AiReply>.value(_replyFor(outcome, request));
    }
  }
}

/// How a [ScriptedSecondary] misbehaves.
enum SecondaryMode {
  /// `ask` throws synchronously.
  throwsSync,

  /// `ask` returns a failed future.
  throwsAsync,

  /// The reply text is empty.
  empty,

  /// The reply is longer than `maxLength`.
  overlong,
}

/// A secondary [CoffinAI] that always misbehaves in one way, for Property 21.
final class ScriptedSecondary implements CoffinAI {
  /// Creates a secondary with the given [mode].
  ScriptedSecondary(this.mode);

  /// A secondary that throws, synchronously when [synchronously] is true.
  ScriptedSecondary.throws({bool synchronously = false})
    : this(
        synchronously ? SecondaryMode.throwsSync : SecondaryMode.throwsAsync,
      );

  /// A secondary that returns an empty reply.
  ScriptedSecondary.empty() : this(SecondaryMode.empty);

  /// A secondary that returns a reply longer than `maxLength`.
  ScriptedSecondary.overlong() : this(SecondaryMode.overlong);

  /// The way this secondary misbehaves.
  final SecondaryMode mode;
  final List<AiRequest> _requests = <AiRequest>[];

  /// How many times `ask` was called.
  int get callCount => _requests.length;

  /// The request objects received, in call order.
  List<AiRequest> get requests => List<AiRequest>.unmodifiable(_requests);

  @override
  Future<AiReply> ask(AiRequest request) {
    _requests.add(request);
    switch (mode) {
      case SecondaryMode.throwsSync:
        throw const _ScriptedFailure();
      case SecondaryMode.throwsAsync:
        return Future<AiReply>.error(const _ScriptedFailure());
      case SecondaryMode.empty:
        return Future<AiReply>.value(
          AiReply(text: '', source: ReplySource.offline),
        );
      case SecondaryMode.overlong:
        return Future<AiReply>.value(
          AiReply(
            text: 'x' * (request.maxLength + 1),
            source: ReplySource.offline,
          ),
        );
    }
  }
}
