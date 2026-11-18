/// Where the home screen is in loading the saved data.
enum HomeStatus {
  /// The saved data is being read.
  loading,

  /// The data is loaded and the haunting can be shown.
  ready,

  /// The saved data could not be read. Calling `load` again retries.
  loadError,
}
