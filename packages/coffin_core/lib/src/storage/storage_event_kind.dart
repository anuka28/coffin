/// What happened to a repository.
enum StorageEventKind {
  /// A record was written, even if its value equals the previous one.
  put,

  /// An existing record was removed.
  delete,

  /// Every record was removed.
  clear,
}
