/// Formats integers with comma thousands separators.
abstract final class ThousandsFormatter {
  /// Formats [value] with a comma between each group of three digits,
  /// counted from the right (`60683` becomes `60,683`).
  ///
  /// A negative value is formatted as `-` followed by its absolute value,
  /// and `-0` is treated as `0`. No locale is used. Works on the text of the
  /// number, so it never overflows (including on the VM's minimum int) and
  /// never throws.
  static String format(int value) {
    final text = value.toString();
    final negative = text.startsWith('-');
    final digits = negative ? text.substring(1) : text;
    if (digits.isEmpty) return text;
    // Guard non-plain-digit text (e.g. exponent form on web) by returning it
    // unchanged rather than inserting misplaced commas.
    for (var i = 0; i < digits.length; i++) {
      final c = digits.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return text;
    }
    if (digits == '0') return '0';
    final buffer = StringBuffer(negative ? '-' : '');
    final lead = digits.length % 3;
    if (lead > 0) buffer.write(digits.substring(0, lead));
    for (var i = lead; i < digits.length; i += 3) {
      if (i > 0) buffer.write(',');
      buffer.write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }
}
