import 'dart:math';

import 'package:coffin_raise/src/workspace/workspace_edit_result.dart';
import 'package:coffin_raise/src/workspace/workspace_editor.dart';
import 'package:coffin_raise/src/workspace/workspace_problem.dart';
import 'package:glados/glados.dart';

/// A generated root pubspec plus the facts the properties need.
final class _Case {
  _Case({
    required this.text,
    required this.name,
    required this.entries,
    required this.eol,
    required this.lastIndent,
    required this.lastItemEndsFile,
  });

  final String text;
  final String name;
  final List<String> entries;
  final String eol;
  final String lastIndent;
  final bool lastItemEndsFile;

  @override
  String toString() =>
      '_Case(name: $name, text: ${text.replaceAll('\r', r'\r').replaceAll('\n', r'\n')})';
}

const List<String> _indents = [' ', '  ', '    ', '\t'];
const List<String> _preamble = [
  'name: coffin_workspace',
  '# a comment',
  '',
  'publish_to: none',
  'description: >-',
];
const List<String> _tail = [
  'environment:',
  '  sdk: ^3.13.0',
  '',
  '# trailing comment',
  'dev_dependencies:',
  '  lints: ^6.0.0',
];

/// Renders a list item for [value] in a random but valid style.
String _item(Random r, String indent, String value) {
  switch (r.nextInt(4)) {
    case 0:
      return '$indent- "$value"';
    case 1:
      return "$indent- '$value'";
    case 2:
      return '$indent- $value # note';
    default:
      return '$indent- $value';
  }
}

/// Builds a pubspec from [seed]. When [mode] is `list`, it has a workspace
/// list; `none` has no list; `listed` also lists `apps/<name>`.
_Case _build(int seed, String mode) {
  final r = Random(seed);
  final eol = r.nextBool() ? '\n' : '\r\n';
  final name = 'n${r.nextInt(1000)}';
  final lines = <String>[];
  for (var i = r.nextInt(4); i > 0; i--) {
    lines.add(_preamble[r.nextInt(_preamble.length)]);
  }
  final entries = <String>[];
  var lastIndent = '  ';
  var lastIsItem = false;
  if (mode == 'none') {
    // Either no key at all, or a key with no list items.
    if (r.nextBool()) {
      lines.add(r.nextBool() ? 'workspace:' : 'workspace: # empty');
    }
  } else {
    lines.add(r.nextBool() ? 'workspace:' : 'workspace: # members');
    final count = 1 + r.nextInt(5);
    final listedAt = mode == 'listed' ? r.nextInt(count) : -1;
    for (var i = 0; i < count; i++) {
      final value = i == listedAt
          ? 'apps/$name'
          : (r.nextBool() ? 'apps/o$i' : 'packages/p$i');
      lastIndent = _indents[r.nextInt(_indents.length)];
      lines.add(_item(r, lastIndent, value));
      if (i != listedAt) entries.add(value);
      if (i < count - 1 && r.nextInt(4) == 0) {
        lines.add(r.nextBool() ? '' : '$lastIndent# between');
      }
    }
    lastIsItem = true;
  }
  var tailLength = r.nextInt(4);
  if (mode == 'none') tailLength = max(tailLength, 1);
  if (lastIsItem && r.nextBool()) tailLength = 0;
  for (var i = 0; i < tailLength; i++) {
    lines.add(_tail[r.nextInt(_tail.length)]);
  }
  final finalNewline = r.nextBool();
  final text = lines.join(eol) + (finalNewline ? eol : '');
  final endsOnItem = lastIsItem && tailLength == 0;
  return _Case(
    text: text,
    name: name,
    entries: entries,
    eol: eol,
    lastIndent: lastIndent,
    lastItemEndsFile: endsOnItem && !finalNewline,
  );
}

/// Removes the one contiguous [inserted] block from [text], or null when
/// [text] holds no position where doing so gives [original].
String? _removeInserted(String text, String inserted, String original) {
  for (
    var i = text.indexOf(inserted);
    i >= 0;
    i = text.indexOf(inserted, i + 1)
  ) {
    final removed = text.substring(0, i) + text.substring(i + inserted.length);
    if (removed == original) return removed;
  }
  return null;
}

void main() {
  group('WorkspaceEditor properties', () {
    // Feature: raise-app, Property 8: Workspace edit adds exactly one last line and nothing else
    // Validates: Requirements 6.1, 6.2, 6.4
    Glados(any.intInRange(0, 1 << 30), ExploreConfig(numRuns: 300)).test(
      'addApp adds exactly one last line and changes nothing else',
      (seed) {
        final c = _build(seed, 'list');
        final result = WorkspaceEditor.addApp(c.text, c.name);
        if (result is! Edited) {
          throw TestFailure('expected Edited for $c, got $result');
        }
        final after = result.pubspec;
        final expected = [...c.entries, 'apps/${c.name}'];
        if (WorkspaceEditor.entries(after).join('|') != expected.join('|')) {
          throw TestFailure(
            'entries ${WorkspaceEditor.entries(after)} != $expected for $c',
          );
        }
        // The inserted line uses the file's own line ending and the last
        // item's indent. When the last item ends the file with no
        // terminator, the line ending between the two items is part of the
        // insertion, so removing it still restores the original.
        final line = '${c.lastIndent}- apps/${c.name}';
        final inserted = c.lastItemEndsFile ? '${c.eol}$line' : '$line${c.eol}';
        if (_removeInserted(after, inserted, c.text) == null) {
          throw TestFailure(
            'removing the inserted line did not give the original for $c; '
            'result: ${after.replaceAll('\r', r'\r').replaceAll('\n', r'\n')}',
          );
        }
        if (after.length != c.text.length + inserted.length) {
          throw TestFailure('more than one line was added for $c');
        }
        // The end-of-file state is preserved.
        if (after.endsWith('\n') != c.text.endsWith('\n')) {
          throw TestFailure('end-of-file state changed for $c');
        }
        // Mixed line endings never appear.
        if (c.eol == '\n' && after.contains('\r')) {
          throw TestFailure('CR introduced into an LF file: $c');
        }
        if (c.eol == '\r\n' && RegExp(r'(?<!\r)\n').hasMatch(after)) {
          throw TestFailure('bare LF introduced into a CRLF file: $c');
        }
      },
    );

    // Feature: raise-app, Property 9 (editor part): Workspace edit refuses unusable files
    // Validates: Requirements 6.3
    Glados(any.intInRange(0, 1 << 30), ExploreConfig(numRuns: 200)).test(
      'addApp returns noWorkspaceList when there is no workspace list',
      (seed) {
        final c = _build(seed, 'none');
        final result = WorkspaceEditor.addApp(c.text, c.name);
        if (result is! NotEdited ||
            result.problem != WorkspaceProblem.noWorkspaceList) {
          throw TestFailure('expected noWorkspaceList for $c, got $result');
        }
      },
    );

    // Feature: raise-app, Property 9 (editor part): Workspace edit refuses unusable files
    // Validates: Requirements 6.3
    Glados(any.intInRange(0, 1 << 30), ExploreConfig(numRuns: 200)).test(
      'addApp returns alreadyListed when apps/<name> is listed',
      (seed) {
        final c = _build(seed, 'listed');
        final result = WorkspaceEditor.addApp(c.text, c.name);
        if (result is! NotEdited ||
            result.problem != WorkspaceProblem.alreadyListed) {
          throw TestFailure('expected alreadyListed for $c, got $result');
        }
      },
    );
  });
}
