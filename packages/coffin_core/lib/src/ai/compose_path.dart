/// How the offline engine reached its text. Tests assert it.
enum ComposePath {
  /// A template that fits was picked and rendered as is.
  picked,

  /// The shortest eligible template was cut to the limit.
  truncated,

  /// The picked template was rendered with its fallback phrases.
  noNameVariant,

  /// Another template of the set was used, in seed-rotated order.
  nextTemplate,

  /// The set's short last resort line was used.
  safeLine,
}
