import 'dart:io';

import 'package:coffin_raise/coffin_raise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temp_root.dart';

const _appName = 'raise_check_app';

void main() {
  test('a raised app passes format, analyze and test', () async {
    final repo = Directory.current.parent.absolute.path;
    final sep = Platform.pathSeparator;
    final temp = tempRoot();
    final root = temp.path;

    // Copy what a raise needs into the temporary root.
    File('$repo${sep}analysis_options.yaml')
        .copySync('$root${sep}analysis_options.yaml');
    File('$repo${sep}pubspec.lock').copySync('$root${sep}pubspec.lock');
    final core = '$repo${sep}packages${sep}coffin_core';
    final coreCopy = '$root${sep}packages${sep}coffin_core';
    Directory(coreCopy).createSync(recursive: true);
    for (final name in ['pubspec.yaml', 'analysis_options.yaml']) {
      File('$core$sep$name').copySync('$coreCopy$sep$name');
    }
    for (final name in ['lib', 'assets']) {
      _copyDir(Directory('$core$sep$name'), Directory('$coreCopy$sep$name'));
    }

    // The root lists only folders that exist in the copy.
    File('$root${sep}pubspec.yaml').writeAsStringSync(
      '# Temporary root for the raise-check test.\n'
      'name: _\n'
      'publish_to: none\n'
      'environment:\n'
      '  sdk: ^3.13.0\n'
      'workspace:\n'
      '  - packages/coffin_core\n'
      'dev_dependencies:\n'
      '  flutter_lints: ^6.0.0\n',
    );

    final result = Raiser().raise(
      targetRoot: temp,
      templateDir: Directory(
        '${Directory.current.absolute.path}${sep}templates${sep}app',
      ),
      appName: _appName,
    );
    expect(
      result,
      isA<RaiseSuccess>(),
      reason: result is RaiseFailure ? result.message : null,
    );

    final appDir = '$root${sep}apps$sep$_appName';
    final analysisOptions = File('$appDir${sep}analysis_options.yaml');
    expect(analysisOptions.existsSync(), isTrue);
    expect(
      analysisOptions.readAsStringSync(),
      contains('include: ../../analysis_options.yaml'),
    );

    Future<ProcessResult> run(List<String> args, String label) async {
      final r = await Process.run(
        args.first,
        args.sublist(1),
        workingDirectory: appDir,
        runInShell: false,
      );
      if (r.exitCode != 0) {
        // ignore: avoid_print
        print(
          '--- $label failed (exit ${r.exitCode}) ---\n'
          'STDOUT:\n${r.stdout}\nSTDERR:\n${r.stderr}',
        );
      }
      expect(r.exitCode, 0, reason: label);
      return r;
    }

    await run(['flutter', 'pub', 'get', '--offline'], 'flutter pub get');
    await run([
      'dart',
      'format',
      '--output=none',
      '--set-exit-if-changed',
      '.',
    ], 'dart format');
    final analyze = await run([
      'flutter',
      'analyze',
      '--no-pub',
    ], 'flutter analyze');
    expect(analyze.stdout.toString(), contains('No issues found!'));
    await run(['flutter', 'test', '--no-pub'], 'flutter test');
  }, tags: 'raise-check');
}

void _copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    final dest = '${to.path}${Platform.pathSeparator}$name';
    if (entity is Directory) {
      _copyDir(entity, Directory(dest));
    } else if (entity is File) {
      entity.copySync(dest);
    }
  }
}
