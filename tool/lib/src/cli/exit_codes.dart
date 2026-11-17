/// Process exit codes of the raise tool.
abstract final class ExitCodes {
  /// The app was raised, or help was printed.
  static const int ok = 0;

  /// The command line was used wrongly (no name, or too many arguments).
  static const int usage = 64;

  /// The input was refused: bad name, existing folder, or a bad pubspec,
  /// template or path.
  static const int badInput = 65;

  /// Reading or writing a file failed.
  static const int ioError = 74;
}
