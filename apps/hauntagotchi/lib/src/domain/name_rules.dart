/// Rules for user-typed habit names.
abstract final class NameRules {
  /// The most characters (Unicode code points) a trimmed name may have.
  static const int maxLength = 40;

  /// Returns null when [raw], trimmed, has 1 to [maxLength] characters.
  /// Otherwise returns a short reason.
  static String? violation(String raw) {
    final length = raw.trim().runes.length;
    if (length == 0) {
      return 'Give it a name.';
    }
    if (length > maxLength) {
      return 'Keep it to $maxLength characters or fewer.';
    }
    return null;
  }

  /// The text that gets stored: [raw] without surrounding whitespace.
  static String normalize(String raw) => raw.trim();
}
