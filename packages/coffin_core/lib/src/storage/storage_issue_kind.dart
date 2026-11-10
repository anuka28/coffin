/// What went wrong when reading or opening storage.
enum StorageIssueKind {
  /// A stored entry could not be parsed or decoded and was skipped.
  corruptRecord,

  /// A migration hook threw, so the entry was skipped.
  migrationFailed,

  /// A stored entry has a version that cannot be read (newer than the
  /// current version, or older with no migration hook), so it was skipped.
  unknownVersion,

  /// Persistent storage was unavailable, so memory storage is used instead.
  fallbackToMemory,
}
