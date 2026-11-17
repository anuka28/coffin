import 'workspace_edit_result.dart';
import 'workspace_problem.dart';

/// Edits and reads a root `pubspec.yaml` line by line, with no YAML parser.
///
/// Only one line is ever inserted. Every other byte of the text, including
/// comments, ordering, line endings and the end-of-file state, is kept.
abstract final class WorkspaceEditor {
  static final RegExp _terminator = RegExp(r'\r\n|\n');
  static final RegExp _workspaceKey = RegExp(r'^workspace:[ \t]*(#.*)?$');
  static final RegExp _item = RegExp(r'^([ \t]*)-[ \t]+(\S.*)$');
  static final RegExp _skippable = RegExp(r'^[ \t]*(#.*)?$');
  static final RegExp _environmentKey = RegExp(r'^environment:[ \t]*(#.*)?$');
  static final RegExp _sdkKey = RegExp(r'^[ \t]+sdk:[ \t]*(\S.*)$');
  static final RegExp _topLevel = RegExp(r'^\S');

  /// Appends `  - apps/<name>` as the last item of the workspace list in
  /// [pubspec].
  ///
  /// The new line copies the indent of the last existing item and uses the
  /// file's own line ending (LF or CRLF). When the last item ends the file
  /// without a line terminator, it gains one and the new line has none, so the
  /// end-of-file state is preserved.
  ///
  /// Returns [NotEdited] with [WorkspaceProblem.noWorkspaceList] when there is
  /// no `workspace:` list, or with [WorkspaceProblem.alreadyListed] when
  /// `apps/<name>` is already an entry (plain, quoted or followed by a
  /// comment).
  static WorkspaceEditResult addApp(String pubspec, String name) {
    final lines = _split(pubspec);
    final list = _findList(lines);
    if (list == null) {
      return const NotEdited(WorkspaceProblem.noWorkspaceList);
    }
    final entry = 'apps/$name';
    for (final index in list.items) {
      if (_itemValue(lines[index].text) == entry) {
        return const NotEdited(WorkspaceProblem.alreadyListed);
      }
    }

    final lastIndex = list.items.last;
    final last = lines[lastIndex];
    final indent = _item.firstMatch(last.text)!.group(1)!;
    final eol = last.terminator.isNotEmpty
        ? last.terminator
        : lines[list.keyIndex].terminator;
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      buffer.write(lines[i].text);
      if (i == lastIndex && last.terminator.isEmpty) {
        buffer
          ..write(eol)
          ..write('$indent- $entry');
      } else {
        buffer.write(lines[i].terminator);
        if (i == lastIndex) {
          buffer
            ..write('$indent- $entry')
            ..write(eol);
        }
      }
    }
    return Edited(buffer.toString());
  }

  /// Returns the value of the `sdk:` line inside the top-level `environment:`
  /// block of [pubspec], without quotes or a trailing comment, or `null` when
  /// there is none.
  static String? sdkConstraint(String pubspec) {
    final lines = _split(pubspec);
    final start = lines.indexWhere((l) => _environmentKey.hasMatch(l.text));
    if (start < 0) return null;
    for (var i = start + 1; i < lines.length; i++) {
      final text = lines[i].text;
      if (_topLevel.hasMatch(text) && !text.startsWith('#')) return null;
      final match = _sdkKey.firstMatch(text);
      if (match != null) {
        final value = _unquote(match.group(1)!);
        return value.isEmpty ? null : value;
      }
    }
    return null;
  }

  /// Returns the items of the `workspace:` list of [pubspec], in order.
  ///
  /// Quotes and trailing comments are removed from each value. The result is
  /// empty when the file has no workspace list.
  static List<String> entries(String pubspec) {
    final lines = _split(pubspec);
    final list = _findList(lines);
    if (list == null) return const [];
    return [for (final i in list.items) _itemValue(lines[i].text)];
  }

  static List<_Line> _split(String text) {
    final lines = <_Line>[];
    var start = 0;
    for (final match in _terminator.allMatches(text)) {
      lines.add(_Line(text.substring(start, match.start), match.group(0)!));
      start = match.end;
    }
    if (start < text.length) lines.add(_Line(text.substring(start), ''));
    return lines;
  }

  /// Finds the `workspace:` key and the item lines that follow it. Blank and
  /// comment-only lines may sit between items. Returns null without items.
  static _WorkspaceList? _findList(List<_Line> lines) {
    final key = lines.indexWhere((l) => _workspaceKey.hasMatch(l.text));
    if (key < 0) return null;
    final items = <int>[];
    for (var i = key + 1; i < lines.length; i++) {
      final text = lines[i].text;
      if (_item.hasMatch(text)) {
        items.add(i);
      } else if (!_skippable.hasMatch(text)) {
        break;
      }
    }
    return items.isEmpty ? null : _WorkspaceList(key, items);
  }

  static String _itemValue(String line) =>
      _unquote(_item.firstMatch(line)!.group(2)!);

  /// Removes surrounding quotes or a trailing ` # comment` from [raw].
  static String _unquote(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    final quote = value[0];
    if (quote == '"' || quote == "'") {
      final close = value.indexOf(quote, 1);
      if (close > 0) return value.substring(1, close);
    }
    final comment = RegExp(r'[ \t]#').firstMatch(value);
    final bare = comment == null ? value : value.substring(0, comment.start);
    return bare.trim();
  }
}

final class _Line {
  const _Line(this.text, this.terminator);

  final String text;
  final String terminator;
}

final class _WorkspaceList {
  const _WorkspaceList(this.keyIndex, this.items);

  final int keyIndex;
  final List<int> items;
}
