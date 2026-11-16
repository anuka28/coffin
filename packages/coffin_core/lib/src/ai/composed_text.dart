import 'compose_path.dart';

/// The text the offline engine wrote and the way it got there.
final class ComposedText {
  /// Creates a result.
  const ComposedText(this.text, this.path);

  /// The reply text.
  final String text;

  /// How the text was reached.
  final ComposePath path;
}
