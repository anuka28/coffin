import 'dart:async';

import 'package:coffin_core/coffin_core.dart';

/// A [CoffinAI] for tests. It never touches the network.
///
/// Each constructor picks one behavior. Every request is recorded in
/// [requests], oldest first, before the behavior runs.
class FakeCoffinAI implements CoffinAI {
  /// Replies at once with [text].
  FakeCoffinAI.replying(String text)
    : _answer = ((AiRequest _) => Future<AiReply>.value(_reply(text)));

  /// Replies with [text] only after [release] is called.
  factory FakeCoffinAI.held(String text) {
    final holder = Completer<void>();
    return FakeCoffinAI._(holder, (AiRequest _) async {
      await holder.future;
      return _reply(text);
    });
  }

  FakeCoffinAI._(this._holder, this._answer);

  /// Completes with [error].
  FakeCoffinAI.failing([Object error = 'fake ai failure'])
    : _answer = ((AiRequest _) => Future<AiReply>.error(error));

  /// Throws [error] synchronously from [ask], which a real `CoffinAI` never
  /// does but a caller should survive.
  FakeCoffinAI.throwing([Object error = 'fake ai failure'])
    : _answer = ((AiRequest _) => throw error);

  /// Never completes.
  FakeCoffinAI.never()
    : _answer = ((AiRequest _) => Completer<AiReply>().future);

  /// Replies at once with empty text.
  FakeCoffinAI.blank() : this.replying('');

  /// Replies at once with text one code unit longer than the request allows.
  FakeCoffinAI.overLength()
    : _answer = ((AiRequest request) =>
          Future<AiReply>.value(_reply('x' * (request.maxLength + 1))));

  final Future<AiReply> Function(AiRequest request) _answer;
  Completer<void>? _holder;
  final List<AiRequest> _requests = <AiRequest>[];

  /// Every request received so far, oldest first.
  List<AiRequest> get requests => List<AiRequest>.unmodifiable(_requests);

  /// Releases a [FakeCoffinAI.held] reply. Does nothing if already released
  /// or if this fake is not held.
  void release() {
    final Completer<void>? holder = _holder;
    if (holder != null && !holder.isCompleted) holder.complete();
  }

  @override
  Future<AiReply> ask(AiRequest request) {
    _requests.add(request);
    return _answer(request);
  }

  static AiReply _reply(String text) =>
      AiReply(text: text, source: ReplySource.offline);
}
