import 'dart:ui';

/// One recorded canvas call: its [method] name and the area it touches.
class RecordedCall {
  /// Creates a record of one call.
  const RecordedCall(this.method, this.bounds);

  /// The `Canvas` method name, for example `drawPath`.
  final String method;

  /// The rectangle the call touches (path bounds, circle center point, clip).
  final Rect bounds;
}

/// A canvas that records, in order, the clip and draw calls with their
/// geometry and ignores everything else.
class GeometryRecordingCanvas implements Canvas {
  /// Every recorded call in the order it was made.
  final List<RecordedCall> calls = <RecordedCall>[];

  /// The calls whose method name is [method].
  List<RecordedCall> of(String method) =>
      calls.where((RecordedCall c) => c.method == method).toList();

  /// The drawing calls (everything except clips).
  List<RecordedCall> get drawings =>
      calls.where((RecordedCall c) => c.method.startsWith('draw')).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String name = invocation.memberName.toString();
    final String method = name.substring(8, name.length - 2);
    final List<dynamic> args = invocation.positionalArguments;
    switch (method) {
      case 'clipRect':
        calls.add(RecordedCall(method, args[0] as Rect));
      case 'drawPath':
        calls.add(RecordedCall(method, (args[0] as Path).getBounds()));
      case 'drawCircle':
        final Offset c = args[0] as Offset;
        calls.add(RecordedCall(method, Rect.fromLTWH(c.dx, c.dy, 0, 0)));
      default:
        if (method.startsWith('draw')) {
          calls.add(RecordedCall(method, Rect.zero));
        }
    }
    return null;
  }
}
