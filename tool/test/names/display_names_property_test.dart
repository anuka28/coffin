import 'package:coffin_raise/src/names/dart_reserved_words.dart';
import 'package:coffin_raise/src/names/display_names.dart';
import 'package:coffin_raise/src/names/name_validator.dart';
import 'package:glados/glados.dart';

/// Characters for the words of a valid name.
const List<String> _wordChars = ['a', 'b', 'c', 'x', 'z', '0', '1', '9'];

extension _AnyValidName on Any {
  /// A name that satisfies every rule: words of `[a-z0-9]` joined by single
  /// underscores, starting with a letter, at most 64 characters, not reserved.
  Generator<String> get validName => combine2(
    choose(const ['a', 'b', 'k', 'z']),
    listWithLengthInRange(
      0,
      8,
      listWithLengthInRange(
        1,
        9,
        choose(_wordChars),
      ).map((chars) => chars.join()),
    ),
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
  group('DisplayNames properties', () {
    // Feature: raise-app, Property 3: Derived names are well formed
    // Validates: Requirements 3.3, 4.4
    Glados(any.validName, ExploreConfig(numRuns: 500)).test(
      'display and class names are well formed for any valid name',
      (n) {
        if (NameValidator.validate(n) != null) {
          throw TestFailure('generator produced an invalid name: "$n"');
        }
        final String display = DisplayNames.displayName(n);
        final String cls = DisplayNames.className(n);
        final List<String> segments = n.split('_');

        if (display.contains('_')) {
          throw TestFailure('display "$display" contains "_" for "$n"');
        }
        final List<String> words = display.split(' ');
        if (words.length != segments.length) {
          throw TestFailure(
            'display "$display" has ${words.length} words, '
            '"$n" has ${segments.length} segments',
          );
        }
        for (final w in words) {
          if (!RegExp(r'^[A-Z0-9]').hasMatch(w)) {
            throw TestFailure('word "$w" of "$display" starts badly');
          }
        }
        if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(cls)) {
          throw TestFailure('class name "$cls" is malformed for "$n"');
        }
        if (display.replaceAll(' ', '') != cls) {
          throw TestFailure('display "$display" without spaces != "$cls"');
        }
      },
    );
  });
}
