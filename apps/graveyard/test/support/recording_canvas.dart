import 'dart:ui';

/// A canvas that counts draw calls by method name and ignores everything else.
class RecordingCanvas implements Canvas {
  /// Number of calls per method name.
  final Map<String, int> calls = <String, int>{};

  /// Returns how many times [method] was called.
  int count(String method) => calls[method] ?? 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    final method = name.substring(8, name.length - 2);
    calls[method] = count(method) + 1;
    return null;
  }
}
