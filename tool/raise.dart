import 'dart:io';

import 'package:coffin_raise/coffin_raise.dart';

/// Entry point: `dart run tool/raise.dart <app_name>`.
void main(List<String> args) {
  exitCode = RaiseCli.run(
    args,
    targetRoot: Directory.current,
    templateDir: RaiseCli.defaultTemplateDir(Platform.script),
    out: stdout,
    err: stderr,
  );
}
