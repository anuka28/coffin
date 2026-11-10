import 'dart:ui' show Color;

import 'wcag_contrast.dart';

/// A foreground/background combination that a token set guarantees.
final class ContrastPair {
  /// Creates a pair of named colors to check for contrast.
  const ContrastPair({
    required this.foregroundName,
    required this.backgroundName,
    required this.foreground,
    required this.background,
  });

  /// Token name of the foreground color, e.g. `text`.
  final String foregroundName;

  /// Token name of the background color, e.g. `surface`.
  final String backgroundName;

  /// The foreground color.
  final Color foreground;

  /// The background color.
  final Color background;

  /// WCAG contrast ratio between [foreground] and [background], in `[1, 21]`.
  double get ratio =>
      WcagContrast.ratio(foreground.toARGB32(), background.toARGB32());

  /// Human-readable description, e.g. `text on surface`.
  String get label => '$foregroundName on $backgroundName';
}
