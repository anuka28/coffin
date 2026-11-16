import 'package:meta/meta.dart';

import 'ai_request.dart';
import 'reply_source.dart';
import 'text_rules.dart';

/// The text a generator returned and where it came from.
///
/// Equality compares [text] and [source]. Construction accepts any string,
/// including empty text, so a wrapper can classify a bad reply instead of
/// failing to build it.
@immutable
final class AiReply {
  /// Creates a reply. Accepts any [text].
  const AiReply({required this.text, required this.source});

  /// The generated text. May be empty or hold only whitespace.
  final String text;

  /// Where the text came from.
  final ReplySource source;

  /// Whether [text] has a non-whitespace character and is at most
  /// `request.maxLength` UTF-16 code units long.
  bool isUsableFor(AiRequest request) =>
      !TextRules.isBlank(text) && text.length <= request.maxLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiReply && other.text == text && other.source == source);

  @override
  int get hashCode => Object.hash(AiReply, text, source);

  /// Prints the source and the text length. Never prints the text, which can
  /// hold a user's ghost or project name.
  @override
  String toString() =>
      'AiReply(source: ${source.name}, length: ${text.length})';
}
