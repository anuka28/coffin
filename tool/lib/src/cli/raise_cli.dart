import 'dart:io';

import '../raise/raise_error_kind.dart';
import '../raise/raise_result.dart';
import '../raise/raiser.dart';
import 'exit_codes.dart';
import 'raise_messages.dart';

/// The command line front end: parses arguments, runs the [Raiser], prints,
/// and returns an exit code. It never exits the process itself.
abstract final class RaiseCli {
  /// Runs the tool for [args] and returns the exit code (see [ExitCodes]).
  ///
  /// Output goes to [out] and errors to [err]. Pass [raiser] to change how
  /// files are written, for example in tests.
  static int run(
    List<String> args, {
    required Directory targetRoot,
    required Directory templateDir,
    required StringSink out,
    required StringSink err,
    Raiser? raiser,
  }) {
    if (args.length == 1 && (args[0] == '--help' || args[0] == '-h')) {
      out.write(RaiseMessages.help());
      return ExitCodes.ok;
    }
    if (args.length != 1) {
      err.write(RaiseMessages.usageError());
      return ExitCodes.usage;
    }
    final name = args[0];
    final result = (raiser ?? Raiser()).raise(
      targetRoot: targetRoot,
      templateDir: templateDir,
      appName: name,
    );
    switch (result) {
      case RaiseSuccess():
        out.write(RaiseMessages.success(name));
        return ExitCodes.ok;
      case RaiseFailure():
        err.write(RaiseMessages.failure(result));
        return result.kind == RaiseErrorKind.ioError
            ? ExitCodes.ioError
            : ExitCodes.badInput;
    }
  }

  /// The template folder next to [script]: `<script dir>/templates/app`.
  static Directory defaultTemplateDir(Uri script) {
    final scriptDir = File.fromUri(script).parent.path;
    final separator = scriptDir.endsWith(Platform.pathSeparator)
        ? ''
        : Platform.pathSeparator;
    return Directory(
      '$scriptDir${separator}templates${Platform.pathSeparator}app',
    );
  }
}
