import 'json_map.dart';

/// Converts records of type [T] to and from JSON maps.
///
/// No adapters and no code generation are needed: describe your record with
/// these two methods and hand the codec to the storage opener.
abstract interface class RecordCodec<T> {
  /// Returns a JSON-safe map for [record].
  ///
  /// Non-finite numbers, integers beyond +/-(2^53 - 1), non-String map keys
  /// and values that are not JSON types make the repository reject the `put`
  /// with an [ArgumentError]. Exceptions thrown here propagate to the caller
  /// of `put` unchanged, and nothing is written.
  JsonMap encode(T record);

  /// Rebuilds a record from [json].
  ///
  /// May throw. When it does, the repository treats the stored entry as
  /// corrupt: the entry is skipped on read, reported as an issue and left
  /// untouched in storage.
  T decode(JsonMap json);
}
