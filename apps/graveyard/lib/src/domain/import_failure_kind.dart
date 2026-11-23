/// Why an import from GitHub did not produce a grave.
enum ImportFailureKind {
  /// The repository does not exist or is private.
  notFoundOrPrivate,

  /// GitHub asked the client to wait.
  rateLimited,

  /// The network could not be reached.
  offline,

  /// GitHub took too long to answer.
  timeout,

  /// The answer could not be understood.
  malformedResponse,

  /// GitHub answered with a status the app does not handle.
  unexpectedStatus,
}
