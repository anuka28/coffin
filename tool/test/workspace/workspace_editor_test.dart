import 'dart:io';

import 'package:coffin_raise/src/workspace/workspace_edit_result.dart';
import 'package:coffin_raise/src/workspace/workspace_editor.dart';
import 'package:coffin_raise/src/workspace/workspace_problem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkspaceEditor.addApp', () {
    test('adds exactly one line to the real root pubspec.yaml', () {
      // Tests run with the package directory (tool/) as working directory.
      final root = File(
        '${Directory.current.absolute.path}${Platform.pathSeparator}..'
        '${Platform.pathSeparator}pubspec.yaml',
      );
      final original = root.readAsStringSync();

      final result = WorkspaceEditor.addApp(original, 'ghoul_tracker');

      final edited = (result as Edited).pubspec;
      final before = original.split('\n');
      final after = edited.split('\n');
      expect(after.length, before.length + 1);
      final entries = WorkspaceEditor.entries(original);
      final lastEntryLine = before.lastIndexWhere(
        (l) => l.contains(entries.last),
      );
      final expected = [
        ...before.sublist(0, lastEntryLine + 1),
        '  - apps/ghoul_tracker',
        ...before.sublist(lastEntryLine + 1),
      ];
      expect(after, expected);
      expect(WorkspaceEditor.entries(edited), [
        ...entries,
        'apps/ghoul_tracker',
      ]);
    });

    test('keeps CRLF line endings', () {
      const input = 'name: _\r\nworkspace:\r\n  - apps/a\r\n  - tool\r\n';

      final result = WorkspaceEditor.addApp(input, 'b');

      expect(
        (result as Edited).pubspec,
        'name: _\r\nworkspace:\r\n  - apps/a\r\n  - tool\r\n  - apps/b\r\n',
      );
    });

    test('keeps a missing final newline missing', () {
      const input = 'workspace:\n  - apps/a\n  - tool';

      final result = WorkspaceEditor.addApp(input, 'b');

      expect(
        (result as Edited).pubspec,
        'workspace:\n  - apps/a\n  - tool\n  - apps/b',
      );
    });

    test('refuses a file without a workspace list', () {
      final result = WorkspaceEditor.addApp('name: _\n', 'b');

      expect(result, isA<NotEdited>());
      expect((result as NotEdited).problem, WorkspaceProblem.noWorkspaceList);
    });
  });

  group('WorkspaceEditor.sdkConstraint', () {
    test('reads the constraint from the real root pubspec.yaml', () {
      final root = File(
        '${Directory.current.absolute.path}${Platform.pathSeparator}..'
        '${Platform.pathSeparator}pubspec.yaml',
      );

      expect(WorkspaceEditor.sdkConstraint(root.readAsStringSync()), isNotNull);
    });

    test('returns null when there is no sdk line', () {
      expect(
        WorkspaceEditor.sdkConstraint(
          'name: _\nenvironment:\n  flutter: any\n',
        ),
        isNull,
      );
      expect(WorkspaceEditor.sdkConstraint('name: _\n'), isNull);
    });
  });
}
