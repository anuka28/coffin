/// Rules for project names: normalisation, length and duplicate keys.
abstract final class NameRules {
  /// The most code points a project name may have.
  static const int maxLength = 80;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Trims [raw] and collapses every whitespace run to a single space.
  static String normalize(String raw) =>
      raw.trim().replaceAll(_whitespace, ' ');

  /// The number of code points in [normalized].
  static int length(String normalized) => normalized.runes.length;

  /// The lower-cased normalised form of [raw], used to detect duplicates.
  static String keyOf(String raw) => normalize(raw).toLowerCase();

  /// The project name for an imported repository.
  ///
  /// Returns the normalised [fullName] when it has at most [maxLength] code
  /// points. Otherwise returns the first `maxLength - 1` code points of the
  /// repo segment (the text after the first slash, or the whole text when
  /// there is no slash) followed by `…`.
  static String forRepo(String fullName) {
    final normalized = normalize(fullName);
    if (length(normalized) <= maxLength) return normalized;
    final slash = normalized.indexOf('/');
    final segment = slash < 0 ? normalized : normalized.substring(slash + 1);
    final kept = segment.runes.take(maxLength - 1);
    return '${String.fromCharCodes(kept)}…';
  }
}
