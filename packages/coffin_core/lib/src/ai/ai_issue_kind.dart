/// Why an AI source was not used for a reply.
enum AiIssueKind {
  /// The source threw an error, or its future completed with one.
  threw,

  /// The source did not answer before the timeout.
  timedOut,

  /// The source replied with blank text.
  emptyReply,

  /// The source replied with text longer than the request allows.
  invalidReply,
}
