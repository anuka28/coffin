/// Shared identifier rules for `AiPurpose` ids and `ReplySource` names.
///
/// Internal to `coffin_core`: not exported by the barrel.
abstract final class IdentifierRules {
  /// Why [id] breaks the rules, or null when it is valid.
  ///
  /// A valid identifier has 1 to [maxLength] UTF-16 code units. The first is
  /// `a` to `z`. Every other one is `a` to `z`, `0` to `9` or `_`. The text
  /// states a length or an index and never repeats [id].
  static String? violation(String id, {required int maxLength}) {
    final int length = id.length;
    if (length < 1 || length > maxLength) {
      return 'length $length is outside the allowed range 1 to $maxLength';
    }
    for (int i = 0; i < length; i++) {
      final int unit = id.codeUnitAt(i);
      final bool lower = unit >= 0x61 && unit <= 0x7A;
      if (i == 0) {
        if (!lower) {
          return 'the first character (index 0) must be a lowercase letter '
              'from a to z';
        }
      } else if (!lower && !(unit >= 0x30 && unit <= 0x39) && unit != 0x5F) {
        return 'the character at index $i is not a lowercase letter, '
            'a digit or an underscore';
      }
    }
    return null;
  }
}
