/// Turns a repository description into plain text for a tombstone.
abstract final class DescriptionCleaner {
  static final RegExp _candidate = RegExp(
    r'(?<=^|\s):([A-Za-z0-9_+-]{1,40}):(?=\s|$)',
  );
  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Removes every whole-word emoji shortcode (such as `:atom:`) from
  /// [description], then collapses each whitespace run to one space and trims
  /// both ends.
  ///
  /// A shortcode is `:name:` with a [name] of 1 to 40 characters from
  /// `A-Za-z0-9_+-` that contains at least one ASCII letter, and that has
  /// whitespace or a string boundary on both sides. Unicode emoji are left
  /// untouched. Never throws.
  static String clean(String description) {
    final withoutCodes = description.replaceAllMapped(
      _candidate,
      (match) => _letter.hasMatch(match.group(1)!) ? ' ' : match.group(0)!,
    );
    return withoutCodes.replaceAll(_whitespace, ' ').trim();
  }
}
