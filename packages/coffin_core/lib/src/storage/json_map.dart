/// A JSON object whose values are JSON-safe: null, bool, finite numbers
/// (integers within +/-(2^53 - 1)), strings, lists of safe values, and maps
/// with String keys and safe values.
typedef JsonMap = Map<String, Object?>;
