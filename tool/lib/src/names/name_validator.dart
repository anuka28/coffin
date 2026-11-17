import 'dart_reserved_words.dart';
import 'name_issue.dart';
import 'name_issue_kind.dart';

/// Checks an app name against Dart package-name rules. Pure: no disk access.
abstract final class NameValidator {
  /// The longest accepted name, in characters.
  static const int maxLength = 64;

  /// Returns null when [name] is acceptable, else the first issue found.
  ///
  /// Check order: empty, too long, bad characters, bad start, bad underscore,
  /// reserved word, taken name, folder exists. [takenNames] holds package
  /// names already in use. [folderExists] says whether `apps/<name>` exists.
  static NameIssue? validate(
    String name, {
    Set<String> takenNames = const {},
    bool folderExists = false,
  }) {
    if (name.isEmpty) {
      return const NameIssue(NameIssueKind.empty, 'The name is empty.');
    }
    if (name.length > maxLength) {
      return const NameIssue(
        NameIssueKind.tooLong,
        'The name is longer than $maxLength characters.',
      );
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) {
      return const NameIssue(
        NameIssueKind.badCharacters,
        'Use only lower-case letters a-z, digits 0-9 and underscores.',
      );
    }
    if (!RegExp(r'^[a-z]').hasMatch(name)) {
      return const NameIssue(
        NameIssueKind.badStart,
        'The name must start with a lower-case letter.',
      );
    }
    if (name.endsWith('_') || name.contains('__')) {
      return const NameIssue(
        NameIssueKind.badUnderscore,
        'Underscores cannot end the name or appear twice in a row.',
      );
    }
    if (dartReservedWords.contains(name)) {
      return NameIssue(
        NameIssueKind.reservedWord,
        '"$name" is a reserved word in Dart.',
      );
    }
    if (takenNames.contains(name)) {
      return NameIssue(
        NameIssueKind.takenByPackage,
        'A package named "$name" already exists or is reserved.',
      );
    }
    if (folderExists) {
      return NameIssue(
        NameIssueKind.folderExists,
        'The folder apps/$name already exists.',
      );
    }
    return null;
  }
}
