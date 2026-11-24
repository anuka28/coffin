/// Deterministic string hash that gives the same value on every platform.
///
/// Unlike `String.hashCode`, the result never changes between runs, the VM
/// and the web.
abstract final class StableHash {
  /// Returns a hash of [text] in `[0, 2^31)`.
  ///
  /// Starts at 7 and folds each UTF-16 code unit `c` with
  /// `h = (h * 31 + c) % 2147483648`. Every intermediate value stays below
  /// 2^53, so the result is identical in JavaScript.
  static int of(String text) {
    var h = 7;
    for (final c in text.codeUnits) {
      h = (h * 31 + c) % 2147483648;
    }
    return h;
  }
}
