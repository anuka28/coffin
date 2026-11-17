import 'placeholders.dart';
import 'render_outcome.dart';

/// Replaces `{{name}}` markers with fixed values in a single pass. Pure.
final class PlaceholderRenderer {
  /// Creates a renderer that substitutes [values], keyed by placeholder name.
  PlaceholderRenderer(Map<String, String> values)
    : _values = Map.unmodifiable(values);

  final Map<String, String> _values;

  /// Replaces every `{{key}}` in [text].
  ///
  /// Returns [UnknownPlaceholder] for the first key (in text order) that has
  /// no value. Replacement values are not scanned again.
  RenderOutcome render(String text) {
    for (final match in Placeholders.pattern.allMatches(text)) {
      final key = match.group(1)!;
      if (!_values.containsKey(key)) return UnknownPlaceholder(key);
    }
    return Rendered(
      text.replaceAllMapped(
        Placeholders.pattern,
        (match) => _values[match.group(1)!]!,
      ),
    );
  }
}
