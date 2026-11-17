/// One file read from the template folder.
final class TemplateFile {
  /// Creates a file at [relativePath] (POSIX separators) holding [bytes].
  const TemplateFile(this.relativePath, this.bytes);

  /// Path relative to the template folder, as stored (may end in `.tmpl`).
  final String relativePath;

  /// The raw file content.
  final List<int> bytes;

  /// Whether this is a text template, meaning the path ends in `.tmpl`.
  ///
  /// Text templates are rendered; all other files are copied unchanged.
  bool get isText => relativePath.endsWith('.tmpl');
}
