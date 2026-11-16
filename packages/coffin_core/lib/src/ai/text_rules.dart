/// Text rules shared by the offline engine: word lists, whitespace, name
/// cleaning and truncation.
///
/// Every rule works on UTF-16 code units and ASCII folding only, so the Dart
/// VM and Flutter Web give the same answer for every input.
abstract final class TextRules {
  /// Gory words. Matched as substrings of the ASCII-lowercased final text.
  static const List<String> bannedWords = <String>[
    'gore',
    'blood',
    'kill',
    'murder',
    'slaughter',
    'mutilat',
    'dismember',
    'decapitat',
    'behead',
    'entrails',
    'viscera',
    'massacre',
    'torture',
    'stabbing',
    'stabbed',
    'severed',
    'bludgeon',
    'strangle',
    'disembowel',
    'maim',
  ];

  /// Mean words. No template or safe line may contain one.
  static const List<String> insultWords = <String>[
    'stupid',
    'idiot',
    'lazy',
    'loser',
    'useless',
    'worthless',
    'pathetic',
    'dumb',
    'failure',
    'hopeless',
    'incompetent',
    'pitiful',
    'ugly',
  ];

  /// Longest cleaned name, in UTF-16 code units.
  static const int maxNameLength = 24;

  /// The ellipsis character, one code unit long.
  static const String ellipsis = '\u2026';

  /// Whether [unit] is in the whitespace set that Dart documents for `trim`.
  ///
  /// The package owns this set so that the VM and web agree for every unit.
  static bool isWhitespaceUnit(int unit) {
    if (unit >= 0x09 && unit <= 0x0D) return true;
    if (unit >= 0x2000 && unit <= 0x200A) return true;
    switch (unit) {
      case 0x20:
      case 0x85:
      case 0xA0:
      case 0x1680:
      case 0x2028:
      case 0x2029:
      case 0x202F:
      case 0x205F:
      case 0x3000:
      case 0xFEFF:
        return true;
    }
    return false;
  }

  /// Whether every unit of [text] is whitespace. An empty string is blank.
  static bool isBlank(String text) {
    for (var i = 0; i < text.length; i++) {
      if (!isWhitespaceUnit(text.codeUnitAt(i))) return false;
    }
    return true;
  }

  /// Maps `A` to `Z` onto `a` to `z` and leaves every other unit unchanged.
  static String asciiLower(String text) {
    final units = List<int>.generate(text.length, text.codeUnitAt);
    var changed = false;
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0x41 && unit <= 0x5A) {
        units[i] = unit + 0x20;
        changed = true;
      }
    }
    return changed ? String.fromCharCodes(units) : text;
  }

  /// Whether the ASCII-lowercased [text] contains a banned word.
  static bool containsBanned(String text) {
    final folded = asciiLower(text);
    for (final word in bannedWords) {
      if (folded.contains(word)) return true;
    }
    return false;
  }

  static bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  static bool _isControl(int unit) =>
      unit < 0x20 || (unit >= 0x7F && unit <= 0x9F);

  /// Cleans a user-typed name.
  ///
  /// Runs of whitespace become one space, edge whitespace is removed, control
  /// units and lone surrogates are dropped, and the result keeps at most
  /// [maxNameLength] units without splitting a surrogate pair. May return an
  /// empty string.
  static String cleanName(String raw) {
    final out = <int>[];
    var pendingSpace = false;
    var i = 0;
    while (i < raw.length) {
      final unit = raw.codeUnitAt(i);
      if (isWhitespaceUnit(unit)) {
        if (out.isNotEmpty) pendingSpace = true;
        i++;
      } else if (_isControl(unit)) {
        i++;
      } else if (_isHigh(unit)) {
        if (i + 1 < raw.length && _isLow(raw.codeUnitAt(i + 1))) {
          if (pendingSpace) out.add(0x20);
          pendingSpace = false;
          out
            ..add(unit)
            ..add(raw.codeUnitAt(i + 1));
          i += 2;
        } else {
          i++;
        }
      } else if (_isLow(unit)) {
        i++;
      } else {
        if (pendingSpace) out.add(0x20);
        pendingSpace = false;
        out.add(unit);
        i++;
      }
    }
    var end = out.length;
    if (end > maxNameLength) {
      end = maxNameLength;
      if (_isHigh(out[end - 1])) end--;
    }
    while (end > 0 && out[end - 1] == 0x20) {
      end--;
    }
    return String.fromCharCodes(out, 0, end);
  }

  /// Shortens [text] to at most [maxLength] units, ending with [ellipsis].
  ///
  /// Precondition: [maxLength] is at least 16, and [text] starts with a
  /// non-whitespace unit and has no lone surrogate. Text that already fits is
  /// returned unchanged.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    var cut = maxLength - 1;
    if (_isHigh(text.codeUnitAt(cut - 1))) cut--;
    while (cut > 0 && isWhitespaceUnit(text.codeUnitAt(cut - 1))) {
      cut--;
    }
    return '${text.substring(0, cut)}$ellipsis';
  }
}
