/// Where the grave list is in its loading life cycle.
enum GraveListStatus {
  /// The list is being read from storage.
  loading,

  /// The list is loaded and can be shown.
  ready,

  /// Reading the list failed. A retry is possible.
  loadError,
}
