import 'package:coffin_raise/src/names/dart_reserved_words.dart';
import 'package:coffin_raise/src/names/name_validator.dart';
import 'package:glados/glados.dart';

/// Characters for the mixed-alphabet strings (valid and invalid).
const List<String> _mixed = [
  'a', 'b', 'z', 'k', '0', '9', '_', 'A', 'Z', '-', '.', '/', ' ', 'é', //
];

/// Characters that are always legal inside a name.
const List<String> _legal = ['a', 'b', 'c', 'x', 'z', '0', '1', '9', '_'];

final List<String> _reserved = dartReservedWords.toList()..sort();

/// One generated case for the property.
class _Case {
  const _Case(this.name, this.taken, this.folderExists);

  final String name;
  final Set<String> taken;
  final bool folderExists;

  @override
  String toString() =>
      '_Case(name: "$name" (${name.length}), taken: $taken, '
      'folderExists: $folderExists)';
}

extension _AnyCase on Any {
  Generator<String> _string(List<String> alphabet, int minLen, int maxLen) =>
      listWithLengthInRange(
        minLen,
        maxLen + 1,
        choose(alphabet),
      ).map((chars) => chars.join());

  Generator<_Case> get nameCase => combine5(
    // Encodes name mode (5), taken-includes-name flag (3) and folder flag (2).
    choose(List<int>.generate(30, (i) => i)),
    _string(_mixed, 0, 80),
    _string(_legal, 0, 80),
    choose(_reserved),
    listWithLengthInRange(0, 4, _string(_legal, 1, 6)),
    (int code, String mixed, String legal, String reserved, List<String> more) {
      final String name = switch (code % 5) {
        0 => mixed,
        1 || 2 => legal,
        3 => reserved,
        _ => 'a' * (60 + legal.length % 10),
      };
      final Set<String> taken = {...more};
      if ((code ~/ 5) % 3 == 1) taken.add(name);
      return _Case(name, taken, (code ~/ 15) % 2 == 1);
    },
  );
}

/// The oracle from design.md: an independent statement of the rules.
bool _oracleAccepts(_Case c) {
  final String s = c.name;
  return RegExp(r'^[a-z](?:[a-z0-9]|_(?=[a-z0-9]))*$').hasMatch(s) &&
      s.length <= 64 &&
      !dartReservedWords.contains(s) &&
      !c.taken.contains(s) &&
      !c.folderExists;
}

void main() {
  group('NameValidator properties', () {
    // Feature: raise-app, Property 1: Name validation matches the package-name rules
    // Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
    Glados(any.nameCase, ExploreConfig(numRuns: 500)).test(
      'validate returns null iff the name satisfies every rule',
      (c) {
        final issue = NameValidator.validate(
          c.name,
          takenNames: c.taken,
          folderExists: c.folderExists,
        );
        final bool expected = _oracleAccepts(c);
        if ((issue == null) != expected) {
          throw TestFailure(
            'Oracle says ${expected ? 'valid' : 'invalid'} but validate '
            'returned ${issue ?? 'null'} for $c',
          );
        }
      },
    );
  });
}
