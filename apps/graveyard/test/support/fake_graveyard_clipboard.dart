import 'package:graveyard/src/ui/graveyard_clipboard.dart';

/// A [GraveyardClipboard] that records every copied text and succeeds.
class RecordingGraveyardClipboard implements GraveyardClipboard {
  /// Creates an empty recording clipboard.
  RecordingGraveyardClipboard();

  final List<String> _copied = <String>[];

  /// Every text passed to [copy], in call order.
  List<String> get copied => List<String>.unmodifiable(_copied);

  @override
  Future<void> copy(String text) async {
    _copied.add(text);
  }
}

/// A [GraveyardClipboard] whose [copy] always throws.
class ThrowingGraveyardClipboard implements GraveyardClipboard {
  /// Creates a clipboard that refuses every copy.
  const ThrowingGraveyardClipboard();

  @override
  Future<void> copy(String text) async {
    throw StateError('clipboard refused');
  }
}
