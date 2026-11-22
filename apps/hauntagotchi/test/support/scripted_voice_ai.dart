import 'dart:async';

import 'package:coffin_core/coffin_core.dart';

/// A test-only [CoffinAI] that records every request and answers each call
/// from a script, in order.
///
/// Queue answers with [replyWith], [replyLater], [failWith] and [hang]. When
/// the script runs out, [ask] returns a future that fails with a [StateError],
/// so a test that makes an unplanned call fails loudly. [ask] never throws
/// synchronously, like the real interface.
final class ScriptedVoiceAi implements CoffinAI {
  /// Creates an empty script. Replies carry [source].
  ScriptedVoiceAi({this.source = ReplySource.offline});

  /// The source given to every text reply.
  final ReplySource source;

  final List<AiRequest> _requests = <AiRequest>[];
  final List<Future<AiReply> Function()> _script =
      <Future<AiReply> Function()>[];

  /// Every request received so far, in call order.
  List<AiRequest> get requests => List<AiRequest>.unmodifiable(_requests);

  /// The number of calls to [ask] so far.
  int get callCount => _requests.length;

  /// The number of scripted answers not used yet.
  int get remaining => _script.length;

  /// Queues an answer that completes at once with [text].
  ScriptedVoiceAi replyWith(String text) {
    _script.add(
      () => Future<AiReply>.value(AiReply(text: text, source: source)),
    );
    return this;
  }

  /// Queues an answer that completes when the test completes the returned
  /// [Completer] with a text. Completing it with an error fails the call.
  Completer<String> replyLater() {
    final Completer<String> completer = Completer<String>();
    _script.add(
      () => completer.future.then(
        (String text) => AiReply(text: text, source: source),
      ),
    );
    return completer;
  }

  /// Queues an answer that completes with [error].
  ScriptedVoiceAi failWith(Object error) {
    _script.add(() => Future<AiReply>.error(error));
    return this;
  }

  /// Queues an answer that never completes.
  ScriptedVoiceAi hang() {
    _script.add(() => Completer<AiReply>().future);
    return this;
  }

  @override
  Future<AiReply> ask(AiRequest request) {
    _requests.add(request);
    if (_script.isEmpty) {
      return Future<AiReply>.error(
        StateError('ScriptedVoiceAi has no answer left for call $callCount'),
      );
    }
    return _script.removeAt(0)();
  }
}
