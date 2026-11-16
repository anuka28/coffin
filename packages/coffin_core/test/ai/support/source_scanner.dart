/// Pure-Dart helpers for the AI source scan. No `dart:io`, so they run on the
/// VM and on Chrome. The file reading lives in the scan test, not here.
///
/// Raw text or code only, per rule (design.md, "Source scan"):
///
/// * Forbidden words, seedless `Random` and `.hashCode` are scanned on the
///   RAW text, comments included. Doc comments must avoid those words.
/// * The public-class counter and the barrel parser work on CODE only
///   (comments removed), because a commented-out class or export is not a
///   declaration.
///
/// A seedless `Random` means `Random()` with no argument. `Random(seed)` is
/// not caught by the regular expressions. It does not need to be, because
/// the `dart:math` rule already forbids the only import that provides it.
library;

/// One scan rule: a [name] shown in failures and the [pattern] to find.
class ScanRule {
  /// Creates a rule.
  const ScanRule(this.name, this.pattern);

  /// A forbidden word, matched case-insensitively as a literal substring.
  factory ScanRule.word(String word) =>
      ScanRule(word, RegExp(RegExp.escape(word), caseSensitive: false));

  /// Label used in failure messages.
  final String name;

  /// What to look for.
  final RegExp pattern;
}

/// One match of a [ScanRule] in a text.
class ScanViolation {
  /// Creates a violation.
  const ScanViolation(this.rule, this.line, this.match);

  /// The [ScanRule.name] that matched.
  final String rule;

  /// 1-based line of the match.
  final int line;

  /// The matched text.
  final String match;

  @override
  String toString() => '$rule at line $line: "$match"';
}

/// The words the AI sources must not contain, in any letter case.
const List<String> forbiddenWords = <String>[
  'http://',
  'https://',
  'api_key',
  'apikey',
  'authorization',
  'bearer',
  'package:http',
  'dart:io',
  'dart:html',
  'HttpClient',
  'package:flutter',
  'DateTime.now',
  'Stopwatch',
  'src/storage',
  'src/router',
  'src/theme',
  'src/widgets',
  'package:go_router',
  'package:hive',
  'riverpod',
  'dart:math',
];

/// One case-insensitive rule per entry of [forbiddenWords].
final List<ScanRule> forbiddenWordRules = List<ScanRule>.unmodifiable(
  forbiddenWords.map(ScanRule.word),
);

/// Matches `Random()` with no argument, not inside a longer name.
final ScanRule seedlessRandomRule = ScanRule(
  'seedless Random()',
  RegExp(r'(?<![A-Za-z0-9_$])Random\s*\(\s*\)'),
);

/// Matches `Random.secure`, not inside a longer name.
final ScanRule secureRandomRule = ScanRule(
  'Random.secure',
  RegExp(r'(?<![A-Za-z0-9_$])Random\.secure'),
);

/// Both seedless-random rules.
final List<ScanRule> seedlessRandomRules = List<ScanRule>.unmodifiable(
  <ScanRule>[seedlessRandomRule, secureRandomRule],
);

/// Matches `.hashCode` member access.
final ScanRule hashCodeRule = ScanRule('.hashCode', RegExp(r'\.hashCode\b'));

/// Returns every match of every rule in the raw [text], ordered by line.
List<ScanViolation> scanText(String text, List<ScanRule> rules) {
  final List<ScanViolation> found = <ScanViolation>[];
  for (final ScanRule rule in rules) {
    for (final RegExpMatch m in rule.pattern.allMatches(text)) {
      found.add(ScanViolation(rule.name, _lineOf(text, m.start), m[0]!));
    }
  }
  found.sort((ScanViolation a, ScanViolation b) => a.line.compareTo(b.line));
  return found;
}

/// Violations of [forbiddenWordRules] in the raw [text].
List<ScanViolation> findForbiddenWords(String text) =>
    scanText(text, forbiddenWordRules);

/// Violations of [seedlessRandomRules] in the raw [text].
List<ScanViolation> findSeedlessRandom(String text) =>
    scanText(text, seedlessRandomRules);

/// Violations of [hashCodeRule] in the raw [text].
List<ScanViolation> findHashCode(String text) =>
    scanText(text, <ScanRule>[hashCodeRule]);

int _lineOf(String text, int offset) {
  int line = 1;
  for (int i = 0; i < offset; i++) {
    if (text.codeUnitAt(i) == 0x0A) line++;
  }
  return line;
}

/// Returns [text] with `//` and (nested) `/* */` comments replaced by spaces.
/// Newlines are kept, so line numbers do not move. String literals are kept
/// as they are, or their contents are blanked when [blankStrings] is true.
String stripComments(String text, {bool blankStrings = false}) {
  final StringBuffer out = StringBuffer();
  final int n = text.length;
  int i = 0;
  while (i < n) {
    final String c = text[i];
    final String next = i + 1 < n ? text[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && text[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (c == '/' && next == '*') {
      int depth = 0;
      while (i < n) {
        final String a = text[i];
        final String b = i + 1 < n ? text[i + 1] : '';
        if (a == '/' && b == '*') {
          depth++;
          out.write('  ');
          i += 2;
        } else if (a == '*' && b == '/') {
          depth--;
          out.write('  ');
          i += 2;
          if (depth == 0) break;
        } else {
          out.write(a == '\n' ? '\n' : ' ');
          i++;
        }
      }
    } else if (c == "'" || c == '"') {
      final bool raw = i > 0 && text[i - 1] == 'r';
      final bool triple = text.startsWith(c * 3, i);
      final String quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < n && !text.startsWith(quote, i)) {
        final String s = text[i];
        if (s == r'\' && !raw && i + 1 < n) {
          out.write(blankStrings ? '  ' : '$s${text[i + 1]}');
          i += 2;
          continue;
        }
        if (!triple && s == '\n') break; // unterminated, stop at line end
        out.write(blankStrings && s != '\n' ? ' ' : s);
        i++;
      }
      if (i < n && text.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

// A type declaration at the start of a line. Extensions that are not
// `extension type` do not match, so they count as zero classes.
final RegExp _declaration = RegExp(
  r'^[ \t]*(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:'
  r'(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*class\s+([A-Za-z_$][\w$]*)'
  r'|enum\s+([A-Za-z_$][\w$]*)'
  r'|(?:base\s+)?mixin\s+(?!class\b)([A-Za-z_$][\w$]*)'
  r'|extension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)'
  r')',
  multiLine: true,
);

/// Names of the public (no leading `_`) type declarations in [source]:
/// `class` with any modifier combination, `enum`, `mixin` and
/// `extension type`. Comments and string contents are ignored. Plain
/// `extension` and `typedef` declarations are not counted.
List<String> publicTypeNames(String source) {
  final String code = stripComments(source, blankStrings: true);
  final List<String> names = <String>[];
  for (final RegExpMatch m in _declaration.allMatches(code)) {
    final String name = m[1] ?? m[2] ?? m[3] ?? m[4]!;
    if (!name.startsWith('_')) names.add(name);
  }
  return names;
}

/// Number of public type declarations in [source]. A typedef-only file has 0.
int countPublicClasses(String source) => publicTypeNames(source).length;

/// One `export` directive of a barrel.
class BarrelExport {
  /// Creates an export record.
  const BarrelExport(this.uri, {this.shown, this.hidden});

  /// The exported library URI.
  final String uri;

  /// Names of the `show` clause, or null when there is none.
  final List<String>? shown;

  /// Names of the `hide` clause, or null when there is none.
  final List<String>? hidden;

  @override
  String toString() => 'export $uri show=$shown hide=$hidden';
}

final RegExp _export = RegExp(
  r'''^\s*export\s+(?:'([^']*)'|"([^"]*)")\s*(?:(show|hide)\s+(.*))?$''',
  dotAll: true,
);

/// Parses the `export` directives of a barrel. Comments are ignored and
/// statements may span several lines. Names in `show` and `hide` lists are
/// returned in source order.
List<BarrelExport> parseBarrelExports(String source) {
  final List<BarrelExport> exports = <BarrelExport>[];
  for (final String statement in stripComments(source).split(';')) {
    final RegExpMatch? m = _export.firstMatch(statement);
    if (m == null) continue;
    final String uri = m[1] ?? m[2]!;
    final String? kind = m[3];
    final List<String>? names = kind == null
        ? null
        : m[4]!
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty)
              .toList();
    exports.add(
      BarrelExport(
        uri,
        shown: kind == 'show' ? names : null,
        hidden: kind == 'hide' ? names : null,
      ),
    );
  }
  return exports;
}
