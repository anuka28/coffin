/// Whether the latest changes have reached storage.
enum SaveStatus {
  /// Every change is written.
  saved,

  /// Writes are in progress.
  saving,

  /// A write failed. The in-memory state is kept and a retry is offered.
  saveError,
}
