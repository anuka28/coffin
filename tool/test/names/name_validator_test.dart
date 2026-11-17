import 'package:coffin_raise/src/names/dart_reserved_words.dart';
import 'package:coffin_raise/src/names/name_issue_kind.dart';
import 'package:coffin_raise/src/names/name_validator.dart';
import 'package:flutter_test/flutter_test.dart';

NameIssueKind? kindOf(String name, {Set<String> taken = const {}}) =>
    NameValidator.validate(name, takenNames: taken)?.kind;

void main() {
  group('NameValidator', () {
    test('accepts a plain name', () {
      expect(NameValidator.validate('bone_shop'), isNull);
      expect(NameValidator.validate('a1'), isNull);
    });

    test('rejects the empty name', () {
      expect(kindOf(''), NameIssueKind.empty);
    });

    test('rejects 65 characters and accepts 64', () {
      expect(kindOf('a' * 65), NameIssueKind.tooLong);
      expect(kindOf('a' * 64), isNull);
    });

    test('rejects dots', () {
      expect(kindOf('bone.shop'), NameIssueKind.badCharacters);
      expect(kindOf('.'), NameIssueKind.badCharacters);
      expect(kindOf('..'), NameIssueKind.badCharacters);
    });

    test('rejects separators', () {
      expect(kindOf('bone-shop'), NameIssueKind.badCharacters);
      expect(kindOf('bone/shop'), NameIssueKind.badCharacters);
      expect(kindOf(r'bone\shop'), NameIssueKind.badCharacters);
      expect(kindOf('bone shop'), NameIssueKind.badCharacters);
    });

    test('rejects upper case and non-ASCII characters', () {
      expect(kindOf('Bone'), NameIssueKind.badCharacters);
      expect(kindOf('café'), NameIssueKind.badCharacters);
      expect(kindOf('héllo'), NameIssueKind.badCharacters);
      expect(kindOf('ghost👻'), NameIssueKind.badCharacters);
    });

    test('rejects bad starts and bad underscores', () {
      expect(kindOf('1bone'), NameIssueKind.badStart);
      expect(kindOf('_bone'), NameIssueKind.badStart);
      expect(kindOf('bone_'), NameIssueKind.badUnderscore);
      expect(kindOf('bone__shop'), NameIssueKind.badUnderscore);
    });

    test('rejects every reserved Dart word', () {
      expect(dartReservedWords, isNotEmpty);
      for (final word in dartReservedWords) {
        expect(kindOf(word), NameIssueKind.reservedWord, reason: word);
      }
    });

    test('rejects coffin_core and flutter_test', () {
      expect(
        kindOf('coffin_core', taken: reservedPackageNames),
        NameIssueKind.takenByPackage,
      );
      expect(
        kindOf('flutter_test', taken: reservedPackageNames),
        NameIssueKind.takenByPackage,
      );
    });

    test('rejects every reserved package name', () {
      expect(reservedPackageNames, contains('coffin_core'));
      expect(reservedPackageNames, contains('flutter_test'));
      expect(reservedPackageNames, hasLength(11));
      for (final name in reservedPackageNames) {
        expect(
          kindOf(name, taken: reservedPackageNames),
          NameIssueKind.takenByPackage,
          reason: name,
        );
      }
    });

    test('rejects a folder that exists, after the other checks', () {
      expect(
        NameValidator.validate('bone', folderExists: true)?.kind,
        NameIssueKind.folderExists,
      );
      expect(
        NameValidator.validate('class', folderExists: true)?.kind,
        NameIssueKind.reservedWord,
      );
    });
  });
}
