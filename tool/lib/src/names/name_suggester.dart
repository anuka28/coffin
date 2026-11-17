import 'dart_reserved_words.dart';
import 'name_validator.dart';

/// Turns a rejected name into a valid one when possible. Pure.
abstract final class NameSuggester {
  /// A valid name derived from [input], or null when none can be derived.
  ///
  /// Lower-cases ASCII letters, turns every run of characters outside
  /// `[a-z0-9]` into one `_`, trims `_`, prefixes `app_` when the result
  /// starts with a digit, truncates to 64 characters, and appends `_app` to
  /// a reserved word. The result is returned only if [NameValidator.validate]
  /// accepts it with [takenNames].
  static String? suggest(String input, {Set<String> takenNames = const {}}) {
    var s = input
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => m[0]!.toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = _trim(s);
    if (s.isEmpty) return null;
    if (RegExp(r'^[0-9]').hasMatch(s)) s = 'app_$s';
    if (s.length > NameValidator.maxLength) {
      s = _trim(s.substring(0, NameValidator.maxLength));
    }
    if (dartReservedWords.contains(s)) s = '${s}_app';
    return NameValidator.validate(s, takenNames: takenNames) == null ? s : null;
  }

  static String _trim(String s) => s.replaceAll(RegExp(r'^_+|_+$'), '');
}
