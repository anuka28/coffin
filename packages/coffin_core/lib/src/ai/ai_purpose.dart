import 'package:meta/meta.dart';

import 'identifier_rules.dart';

/// What a piece of generated text is for.
///
/// Equality is on [id] only, so a custom purpose that reuses a known
/// identifier equals the known constant.
@immutable
final class AiPurpose {
  /// Creates a purpose with a custom [id]. Throws [ArgumentError] when [id]
  /// breaks the rules in [violation].
  factory AiPurpose(String id) {
    final String? problem = violation(id);
    if (problem != null) {
      throw ArgumentError.value(id.length, 'id.length', problem);
    }
    return AiPurpose._(id);
  }

  const AiPurpose._(this.id);

  /// Short mood line for a ghost. Identifier `ghost_mood_line`.
  static const AiPurpose ghostMoodLine = AiPurpose._('ghost_mood_line');

  /// Verdict of a séance over an abandoned project. Identifier
  /// `seance_verdict`.
  static const AiPurpose seanceVerdict = AiPurpose._('seance_verdict');

  /// Longest allowed identifier, in UTF-16 code units.
  static const int maxIdLength = 64;

  /// Why [id] is not a valid identifier, or null when it is valid. The text
  /// states a length or an index and never repeats the identifier.
  static String? violation(String id) =>
      IdentifierRules.violation(id, maxLength: maxIdLength);

  /// The identifier. Never shown to the user.
  final String id;

  @override
  bool operator ==(Object other) => other is AiPurpose && other.id == id;

  @override
  int get hashCode => Object.hash(AiPurpose, id);

  @override
  String toString() => 'AiPurpose($id)';
}
