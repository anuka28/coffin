/// The ways an app name can be rejected, in the order they are checked.
enum NameIssueKind {
  /// The name is empty.
  empty,

  /// The name is longer than 64 characters.
  tooLong,

  /// The name has a character outside `a-z`, `0-9` and `_`.
  badCharacters,

  /// The name does not start with a lower-case letter.
  badStart,

  /// The name starts or ends with `_`, or has `__` inside.
  badUnderscore,

  /// The name is a Dart reserved word or built-in identifier.
  reservedWord,

  /// The name is already used by a package or is in the reserved package set.
  takenByPackage,

  /// The folder `apps/<name>` already exists.
  folderExists,
}
