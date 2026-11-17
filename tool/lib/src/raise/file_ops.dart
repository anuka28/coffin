import 'dart:io';

/// The small set of disk operations the raise needs.
///
/// Every write goes through this interface so tests can record calls and
/// inject failures. Paths are plain strings.
abstract interface class FileOps {
  /// Creates the directory at [path]. The parent must exist.
  void createDirectory(String path);

  /// Creates the file at [path] with [bytes]. Throws when it already exists.
  void createFileExclusive(String path, List<int> bytes);

  /// Replaces the file at [path] with [bytes] by writing a temporary sibling
  /// and renaming it over the target.
  void replaceFile(String path, List<int> bytes);

  /// Deletes the file at [path].
  void deleteFile(String path);

  /// Deletes the directory at [path]. Throws when it is not empty.
  void deleteEmptyDirectory(String path);

  /// Returns the bytes of the file at [path], or null when it is missing.
  List<int>? readFile(String path);

  /// Returns the names (not paths) of the entries directly inside [path].
  List<String> listDirectory(String path);

  /// Returns the type of the entry at [path] without following symbolic links.
  FileSystemEntityType typeOf(String path);
}
