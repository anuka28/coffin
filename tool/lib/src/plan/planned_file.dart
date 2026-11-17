/// One file the raise will create, with its final content.
final class PlannedFile {
  /// Creates a file at [relativePath] holding [bytes].
  const PlannedFile(this.relativePath, this.bytes);

  /// Path relative to `apps/<name>/`, with POSIX separators and no `.tmpl`.
  final String relativePath;

  /// The final file content.
  final List<int> bytes;
}
