import '../raise/raise_error_kind.dart';
import '../raise/raise_result.dart';
import 'exit_codes.dart';

/// All text the raise tool prints.
abstract final class RaiseMessages {
  /// The one-line usage reminder.
  static const String usageLine = 'Usage: dart run tool/raise.dart <app_name>';

  /// Printed to stderr when the arguments are wrong.
  static String usageError() =>
      'A name is needed, and only one.\n'
      '$usageLine\n'
      'Try --help for the full scroll.\n';

  /// Printed to stdout for `--help`. Lists every exit code.
  static String help() =>
      '$usageLine\n'
      '       dart run tool/raise.dart --help\n'
      '\n'
      'Raises a new Coffin app into apps/<app_name> and lists it in the root\n'
      'pubspec.yaml workspace.\n'
      '\n'
      'Example:\n'
      '  dart run tool/raise.dart bone_shop\n'
      '\n'
      'Exit codes:\n'
      '  ${ExitCodes.ok}   the app was raised (or help was shown)\n'
      '  ${ExitCodes.usage}  wrong arguments\n'
      '  ${ExitCodes.badInput}  the name, folder, pubspec or template was refused\n'
      '  ${ExitCodes.ioError}  a file could not be read or written\n';

  /// Printed to stdout when `apps/<name>` was raised.
  static String success(String name) =>
      'Raised apps/$name. It lives.\n'
      'Next:\n'
      '  flutter pub get\n'
      '  (cd apps/$name && flutter run -d chrome)\n'
      '  (cd apps/$name && flutter test)\n'
      'Open apps/$name in Kiro to load its steering\n';

  /// Printed to stderr for a failed raise: a spooky line, the plain reason,
  /// and the suggestion when there is one.
  static String failure(RaiseFailure failure) {
    final buffer = StringBuffer()
      ..writeln(_opening(failure.kind))
      ..writeln('Reason: ${failure.message}');
    final suggestion = failure.suggestion;
    if (suggestion != null) {
      buffer.writeln('Try this name instead: $suggestion');
    }
    return buffer.toString();
  }

  static String _opening(RaiseErrorKind kind) => switch (kind) {
    RaiseErrorKind.invalidName => 'The crypt will not take that name.',
    RaiseErrorKind.folderExists => 'Something already rests there.',
    RaiseErrorKind.pubspecProblem => 'The workspace scroll is not in order.',
    RaiseErrorKind.templateProblem => 'The template has a loose thread.',
    RaiseErrorKind.unsafePath => 'That path wanders outside the crypt.',
    RaiseErrorKind.ioError => 'The ground would not budge.',
  };
}
