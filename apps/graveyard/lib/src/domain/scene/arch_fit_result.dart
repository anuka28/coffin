/// Where and how large to draw the epitaph line inside a tombstone arch.
class ArchFitResult {
  /// Creates an arch fit result.
  const ArchFitResult({
    required this.top,
    required this.fontSize,
    required this.truncated,
  });

  /// Vertical position of the line's top edge, measured down from the top of
  /// the arch.
  final double top;

  /// Font size to draw with, from 12 up to the requested base size.
  final double fontSize;

  /// Whether the text still needs an ellipsis at the minimum font size.
  final bool truncated;

  @override
  bool operator ==(Object other) =>
      other is ArchFitResult &&
      other.top == top &&
      other.fontSize == fontSize &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(top, fontSize, truncated);

  @override
  String toString() =>
      'ArchFitResult(top: $top, fontSize: $fontSize, truncated: $truncated)';
}
