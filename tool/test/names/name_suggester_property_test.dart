import 'package:coffin_raise/src/names/dart_reserved_words.dart';
import 'package:coffin_raise/src/names/name_suggester.dart';
import 'package:coffin_raise/src/names/name_validator.dart';
import 'package:glados/glados.dart';

/// Characters for arbitrary input: letters, digits, separators, non-ASCII.
const List<String> _inputChars = [
  'a', 'b', 'z', 'Q', 'Z', '0', '7', '_', '-', '.', '/', ' ', '\t', 'é', //
  '👻', '{', '\u0000',
];

/// Characters for names that are valid by construction.
const List<String> _wordChars = ['a', 'b', 'c', 'x', 'z', '0', '1', '9'];

/// One generated suggestion case.
class _Case {
  const _Case(this.input, this.taken);

  final String input;
  final Set<String> taken;

  @override
  String toString() => '_Case(input: "$input", taken: $taken)';
}

extension _AnySuggest on Any {
  Generator<String> _string(List<String> alphabet, int minLen, int maxLen) =>
      listWithLengthInRange(
        minLen,
        maxLen + 1,
        choose(alphabet),
      ).map((chars) => chars.join());

  Generator<_Case> get suggestCase => combine3(
    _string(_inputChars, 0, 100),
    listWithLengthInRange(0, 4, _string(_wordChars, 1, 8)),
    choose(<int>[0, 1, 2]),
    (String input, List<String> more, int mode) {
      final Set<String> taken = {...more};
      // Sometimes make the obvious derived name taken, to hit the null path.
      if (mode == 1) {
        final String? plain = NameSuggester.suggest(input);
        if (plain != null) taken.add(plain);
      }
      return _Case(input, taken);
    },
  );

  /// A name that satisfies every rule: words of `[a-z0-9]` joined by single
  /// underscores, starting with a letter, at most 64 characters, not reserved.
  Generator<String> get validName => combine2(
    choose(const ['a', 'b', 'k', 'z']),
    listWithLengthInRange(0, 8, _string(_wordChars, 1, 8)),
    (String first, List<String> words) {
      var name = [first, ...words].join('_');
      if (name.length > NameValidator.maxLength) {
        name = name.substring(0, NameValidator.maxLength);
        name = name.replaceAll(RegExp(r'_+$'), '');
      }
      return dartReservedWords.contains(name) ? '${name}1' : name;
    },
  );
}

void main() {
  group('NameSuggester properties', () {
    // Feature: raise-app, Property 2: A suggestion is always a valid name
    // Validates: Requirements 2.7
    Glados(any.suggestCase, ExploreConfig(numRuns: 500)).test(
      'a returned suggestion passes NameValidator.validate',
      (c) {
        final String? n = NameSuggester.suggest(c.input, takenNames: c.taken);
        if (n == null) return;
        final issue = NameValidator.validate(n, takenNames: c.taken);
        if (issue != null) {
          throw TestFailure(
            'suggest returned "$n" but validate said ${issue.kind}: '
            '${issue.reason} for $c',
          );
        }
      },
    );

    // Feature: raise-app, Property 2: A suggestion is always a valid name
    // Validates: Requirements 2.7
    Glados(any.validName, ExploreConfig(numRuns: 500)).test(
      'suggest returns an already valid name unchanged',
      (v) {
        if (NameValidator.validate(v) != null) {
          throw TestFailure('generator produced an invalid name: "$v"');
        }
        final String? n = NameSuggester.suggest(v);
        if (n != v) {
          throw TestFailure(
            'suggest("$v") returned ${n == null ? 'null' : '"$n"'}',
          );
        }
      },
    );
  });
}
