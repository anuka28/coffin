/// The category of a failed raise. The CLI maps each kind to an exit code.
enum RaiseErrorKind {
  /// The app name breaks a naming rule or clashes with a package.
  invalidName,

  /// `apps/<name>` already exists.
  folderExists,

  /// The root `pubspec.yaml` is missing or cannot take the new entry.
  pubspecProblem,

  /// The template folder is empty or uses an unknown placeholder.
  templateProblem,

  /// A rendered template path would leave `apps/<name>/`.
  unsafePath,

  /// Reading or writing a file failed.
  ioError,
}
