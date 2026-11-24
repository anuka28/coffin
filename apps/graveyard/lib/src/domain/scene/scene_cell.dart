/// Position and size of one tombstone in the scene grid.
final class SceneCell {
  /// Creates a cell at [row] and [column] with its top-left corner at
  /// ([left], [top]) and a tombstone [width].
  const SceneCell({
    required this.row,
    required this.column,
    required this.left,
    required this.top,
    required this.width,
  });

  /// Zero-based row, `index ~/ columns`.
  final int row;

  /// Zero-based column, `index % columns`.
  final int column;

  /// Horizontal offset of the tombstone's left edge in logical pixels.
  final double left;

  /// Vertical offset of the tombstone's top edge in logical pixels.
  final double top;

  /// Tombstone width in logical pixels.
  final double width;

  @override
  bool operator ==(Object other) =>
      other is SceneCell &&
      other.row == row &&
      other.column == column &&
      other.left == left &&
      other.top == top &&
      other.width == width;

  @override
  int get hashCode => Object.hash(row, column, left, top, width);

  @override
  String toString() =>
      'SceneCell(row: $row, column: $column, left: $left, top: $top, '
      'width: $width)';
}
