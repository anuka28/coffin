/// Fixed copy for the ghost voice.
abstract final class VoiceCopy {
  /// The warm line shown when no AI line is available. One line of plain
  /// ASCII, at most 80 characters.
  static const String safeLine = 'Your ghost is here, floating softly nearby.';

  /// The name used when the ghost name is empty.
  static const String fallbackName = 'Wisp';

  /// The screen reader label for [line]: `'<ghostName> says: <line>'`.
  ///
  /// An empty [ghostName] is replaced by [fallbackName].
  static String label(String ghostName, String line) =>
      '${ghostName.isEmpty ? fallbackName : ghostName} says: $line';
}
