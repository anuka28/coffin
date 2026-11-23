/// Whether changes to the grave list have reached storage.
enum SaveStatus {
  /// Every change is written.
  saved,

  /// A write is running.
  saving,

  /// A write failed. The change is kept in memory and can be retried.
  saveError,
}
