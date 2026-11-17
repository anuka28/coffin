import 'package:coffin_raise/src/cli/raise_messages.dart';
import 'package:coffin_raise/src/names/dart_reserved_words.dart';
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
  group('RaiseMessages properties', () {
    // Feature: raise-app, Property 4: Success message names the folder, the three commands and the Kiro line
    // Validates: Requirements 1.2, 1.8, 1.9
    Glados(any.validName, ExploreConfig(numRuns: 500)).test(
      'success message names the folder, the three commands and the Kiro line',
      (n) {
        if (NameValidator.validate(n) != null) {
          throw TestFailure('generator produced an invalid name: "$n"');
        }
        final String message = RaiseMessages.success(n);
        final List<String> lines = message.split('\n');
        final List<String> trimmed = lines.map((l) => l.trim()).toList();

        if (!message.contains('apps/$n')) {
          throw TestFailure('message does not name apps/$n:\n$message');
        }
        if (!trimmed.contains('flutter pub get')) {
          throw TestFailure('missing "flutter pub get" for "$n":\n$message');
        }
        final bool hasRun = lines.any(
          (l) => l.contains('apps/$n') && l.contains('flutter run -d chrome'),
        );
        if (!hasRun) {
          throw TestFailure(
            'missing "flutter run -d chrome" in apps/$n:\n$message',
          );
        }
        final bool hasTest = lines.any(
          (l) => l.contains('apps/$n') && l.contains('flutter test'),
        );
        if (!hasTest) {
          throw TestFailure('missing "flutter test" in apps/$n:\n$message');
        }
        if (!lines.contains('Open apps/$n in Kiro to load its steering')) {
          throw TestFailure('missing exact Kiro line for "$n":\n$message');
        }
      },
    );
  });
}
