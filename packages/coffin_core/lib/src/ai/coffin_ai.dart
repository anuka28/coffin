import 'ai_reply.dart';
import 'ai_request.dart';

/// A source of short spooky text. [ask] completes with a reply, or completes
/// with an error when the implementation cannot answer. It never throws
/// synchronously and has no cancellation.
abstract interface class CoffinAI {
  /// Answers [request].
  Future<AiReply> ask(AiRequest request);
}
