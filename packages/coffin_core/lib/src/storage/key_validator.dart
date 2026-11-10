/// The single definition of a valid storage key, shared by every repository.
///
/// A valid key is non-empty, at most [maxLength] UTF-16 code units long, and
/// made only of code units up to [maxCodeUnit] (ASCII). This is a deliberate
/// subset of what `hive_ce` accepts.
abstract final class KeyValidator {
  /// Longest valid key, in UTF-16 code units.
  static const int maxLength = 255;

  /// Highest valid code unit (ASCII DEL).
  static const int maxCodeUnit = 0x7F;

  /// Why [key] is invalid, or null when it is valid.
  ///
  /// The message states a length or an index, never the key text.
  static String? violation(String key) {
    if (key.isEmpty) {
      return 'must not be empty';
    }
    if (key.length > maxLength) {
      return 'longer than $maxLength code units (was ${key.length})';
    }
    final units = key.codeUnits;
    for (var i = 0; i < units.length; i++) {
      if (units[i] > maxCodeUnit) {
        return 'contains a code unit above 0x7F at index $i';
      }
    }
    return null;
  }

  /// True when [key] is valid.
  static bool isValid(String key) => violation(key) == null;

  /// Throws [ArgumentError] with the reason when [key] is invalid.
  static void check(String key) {
    final reason = violation(key);
    if (reason != null) {
      throw ArgumentError('Invalid storage key: $reason');
    }
  }
}
