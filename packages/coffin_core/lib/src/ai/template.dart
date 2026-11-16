import 'ai_fact_keys.dart';
import 'clean_facts.dart';

/// One line pattern with slots, parsed once.
///
/// Grammar:
///
/// * A count slot is `{key:singular/plural}`. The key is `streakCount` or
///   `daysSinceLastCommit`. It renders `<number> <noun>`, with the singular
///   noun only for 1. The number is plain decimal digits.
/// * A name slot is `{key|fallback}`. The key is `ghostName` or
///   `projectName`. It renders the cleaned name, or the fallback text when
///   the name is missing or when names are switched off.
///
/// Braces appear only as slot delimiters. The constructor throws
/// [StateError] for a bad pattern, so a bad pattern fails on first use.
final class Template {
  /// Parses [pattern]. Throws [StateError] for an unknown key, a missing
  /// noun or fallback, a count slot with `|`, a name slot with `:` or a
  /// stray brace.
  Template(String pattern) : _parts = _parse(pattern);

  final List<_Part> _parts;

  static const Set<String> _countKeys = {
    AiFactKeys.streakCount,
    AiFactKeys.daysSinceLastCommit,
  };
  static const Set<String> _nameKeys = {
    AiFactKeys.ghostName,
    AiFactKeys.projectName,
  };

  /// Whether every count slot has its fact in [facts].
  bool isEligible(CleanFacts facts) {
    for (final part in _parts) {
      if (part is _CountSlot && _count(facts, part.key) == null) return false;
    }
    return true;
  }

  /// The number of slots filled from a real fact: every count slot (when
  /// eligible) and every name slot whose name is present.
  int usedFacts(CleanFacts facts) {
    var used = 0;
    for (final part in _parts) {
      if (part is _CountSlot && _count(facts, part.key) != null) used++;
      if (part is _NameSlot && _name(facts, part.key) != null) used++;
    }
    return used;
  }

  /// Whether a name slot would be filled from a real name in [facts].
  bool usesRealName(CleanFacts facts) {
    for (final part in _parts) {
      if (part is _NameSlot && _name(facts, part.key) != null) return true;
    }
    return false;
  }

  /// Fills the slots from [facts].
  ///
  /// With [useNames] false every name slot shows its fallback. Throws
  /// [StateError] when a count slot has no fact; check [isEligible] first.
  String render(CleanFacts facts, {bool useNames = true}) {
    final out = StringBuffer();
    for (final part in _parts) {
      switch (part) {
        case _Literal():
          out.write(part.text);
        case _CountSlot():
          final n = _count(facts, part.key);
          if (n == null) {
            throw StateError('Missing count fact: ${part.key}');
          }
          out
            ..write(n)
            ..write(' ')
            ..write(n == 1 ? part.singular : part.plural);
        case _NameSlot():
          final name = useNames ? _name(facts, part.key) : null;
          out.write(name ?? part.fallback);
      }
    }
    return out.toString();
  }

  static int? _count(CleanFacts facts, String key) =>
      key == AiFactKeys.streakCount
      ? facts.streakCount
      : facts.daysSinceLastCommit;

  static String? _name(CleanFacts facts, String key) =>
      key == AiFactKeys.ghostName ? facts.ghostName : facts.projectName;

  static List<_Part> _parse(String pattern) {
    final parts = <_Part>[];
    final literal = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      final c = pattern[i];
      if (c == '}') {
        throw StateError('Stray "}" in template: $pattern');
      }
      if (c != '{') {
        literal.write(c);
        i++;
        continue;
      }
      final close = pattern.indexOf('}', i + 1);
      if (close < 0) {
        throw StateError('Unclosed "{" in template: $pattern');
      }
      final body = pattern.substring(i + 1, close);
      if (body.contains('{')) {
        throw StateError('Stray "{" in template: $pattern');
      }
      if (literal.isNotEmpty) {
        parts.add(_Literal(literal.toString()));
        literal.clear();
      }
      parts.add(_parseSlot(body, pattern));
      i = close + 1;
    }
    if (literal.isNotEmpty) parts.add(_Literal(literal.toString()));
    return List<_Part>.unmodifiable(parts);
  }

  static _Part _parseSlot(String body, String pattern) {
    final sep = body.indexOf(RegExp('[:|]'));
    final key = sep < 0 ? body : body.substring(0, sep);
    final isCount = _countKeys.contains(key);
    if (!isCount && !_nameKeys.contains(key)) {
      throw StateError('Unknown slot key "$key" in template: $pattern');
    }
    if (isCount) {
      if (body.contains('|')) {
        throw StateError('Count slot "$key" cannot have "|": $pattern');
      }
      if (sep < 0) {
        throw StateError('Count slot "$key" needs nouns: $pattern');
      }
      final nouns = body.substring(sep + 1).split('/');
      if (nouns.length != 2 || nouns[0].isEmpty || nouns[1].isEmpty) {
        throw StateError('Count slot "$key" needs singular/plural: $pattern');
      }
      return _CountSlot(key, nouns[0], nouns[1]);
    }
    if (sep >= 0 && body[sep] == ':') {
      throw StateError('Name slot "$key" cannot have ":": $pattern');
    }
    if (sep < 0 || sep == body.length - 1) {
      throw StateError('Name slot "$key" needs a fallback: $pattern');
    }
    return _NameSlot(key, body.substring(sep + 1));
  }
}

sealed class _Part {
  const _Part();
}

final class _Literal extends _Part {
  const _Literal(this.text);
  final String text;
}

final class _CountSlot extends _Part {
  const _CountSlot(this.key, this.singular, this.plural);
  final String key;
  final String singular;
  final String plural;
}

final class _NameSlot extends _Part {
  const _NameSlot(this.key, this.fallback);
  final String key;
  final String fallback;
}
