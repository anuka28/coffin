/// The result of rendering one piece of template text.
sealed class RenderOutcome {
  const RenderOutcome();
}

/// Rendering succeeded; [text] has every placeholder replaced.
final class Rendered extends RenderOutcome {
  /// Creates a successful outcome holding [text].
  const Rendered(this.text);

  /// The rendered text.
  final String text;
}

/// Rendering stopped at a placeholder with no value.
final class UnknownPlaceholder extends RenderOutcome {
  /// Creates an outcome naming the first unknown [key].
  const UnknownPlaceholder(this.key);

  /// The placeholder name, without braces.
  final String key;
}
