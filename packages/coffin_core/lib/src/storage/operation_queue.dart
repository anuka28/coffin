/// Runs async operations one at a time, in the order they were submitted.
final class OperationQueue {
  /// Creates an empty queue.
  OperationQueue();

  // Never completes with an error: failures are swallowed before they reach it.
  Future<void> _tail = Future<void>.value();

  /// Runs [operation] after every earlier operation has finished (successfully
  /// or not).
  ///
  /// The returned future completes with the operation's own result or error.
  /// A failure never blocks later operations, and it is never reported as an
  /// unhandled error on behalf of the queue: only the caller sees it. An
  /// operation that throws synchronously is treated like one that fails.
  Future<R> run<R>(Future<R> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}
