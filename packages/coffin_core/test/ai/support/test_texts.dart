// Pure support code: no dart:io, no hive_ce, no Flutter. It runs in Chrome.
//
// Everything here is the test's own copy. Nothing is read from `TextRules`,
// so weakening the shipped lists cannot weaken the tests that check them.

/// The 20 gory words. Test-declared copy of the design's Banned_Words.
const List<String> testBannedWords = <String>[
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

/// The 13 mean words. Test-declared copy of the design's Insult_Words.
const List<String> testInsultWords = <String>[
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

/// The whitespace code units: U+0009 to U+000D, U+0020, U+0085, U+00A0,
/// U+1680, U+2000 to U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF.
final Set<int> testWhitespaceUnits = <int>{
  for (int u = 0x09; u <= 0x0D; u++) u,
  0x20,
  0x85,
  0xA0,
  0x1680,
  for (int u = 0x2000; u <= 0x200A; u++) u,
  0x2028,
  0x2029,
  0x202F,
  0x205F,
  0x3000,
  0xFEFF,
};

/// True when [unit] is in [testWhitespaceUnits].
bool isTestWhitespace(int unit) => testWhitespaceUnits.contains(unit);

/// True when every code unit of [text] is whitespace. Empty is blank.
bool isTestBlank(String text) => text.codeUnits.every(isTestWhitespace);

/// Lowercases `A` to `Z` only. Every other unit is kept.
String asciiFold(String text) => String.fromCharCodes(<int>[
  for (final int u in text.codeUnits) (u >= 0x41 && u <= 0x5A) ? u + 0x20 : u,
]);

/// True when [text], folded, contains a word of [testBannedWords].
bool hasTestBannedWord(String text) {
  final String folded = asciiFold(text);
  return testBannedWords.any(folded.contains);
}

/// True when [text], folded, contains a word of [testInsultWords].
bool hasTestInsultWord(String text) {
  final String folded = asciiFold(text);
  return testInsultWords.any(folded.contains);
}

bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;
bool _isLow(int u) => u >= 0xDC00 && u <= 0xDFFF;

/// True when [text] has a surrogate that is not half of a valid pair.
bool hasLoneSurrogate(String text) {
  final List<int> units = text.codeUnits;
  for (int i = 0; i < units.length; i++) {
    final int u = units[i];
    if (_isHigh(u)) {
      if (i + 1 < units.length && _isLow(units[i + 1])) {
        i++;
      } else {
        return true;
      }
    } else if (_isLow(u)) {
      return true;
    }
  }
  return false;
}

/// True when [text] starts or ends with a whitespace unit.
bool hasEdgeWhitespace(String text) =>
    text.isNotEmpty &&
    (isTestWhitespace(text.codeUnits.first) ||
        isTestWhitespace(text.codeUnits.last));

/// Counts emoji in [text]: each surrogate pair for U+1F000 to U+1FFFF, and
/// each BMP symbol from U+2600 to U+27BF. The ellipsis is not an emoji.
int countEmoji(String text) {
  final List<int> units = text.codeUnits;
  int count = 0;
  for (int i = 0; i < units.length; i++) {
    final int u = units[i];
    if (_isHigh(u) && i + 1 < units.length && _isLow(units[i + 1])) {
      final int point =
          0x10000 + ((u - 0xD800) << 10) + (units[i + 1] - 0xDC00);
      if (point >= 0x1F000 && point <= 0x1FFFF) count++;
      i++;
    } else if (u >= 0x2600 && u <= 0x27BF) {
      count++;
    }
  }
  return count;
}
