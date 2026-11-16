import 'ai_reply.dart';
import 'ai_request.dart';
import 'coffin_ai.dart';
import 'offline_engine.dart';
import 'reply_source.dart';

/// A [CoffinAI] that writes its text on the device, with no network and no
/// key.
///
/// It is a thin shell over the standard offline engine. The same request
/// always gives the same reply, and the reply always fits `maxLength`. The
/// future completes in the next microtask and never fails.
final class OfflineCoffinAI implements CoffinAI {
  /// Creates the offline generator. It holds no state, so one `const`
  /// instance can be shared.
  const OfflineCoffinAI();

  @override
  Future<AiReply> ask(AiRequest request) => Future<AiReply>.value(
    AiReply(
      text: OfflineEngine.standard.compose(request).text,
      source: ReplySource.offline,
    ),
  );
}
