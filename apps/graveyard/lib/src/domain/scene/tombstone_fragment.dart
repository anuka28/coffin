import 'tombstone_fragment_kind.dart';

/// One piece of visible text on a tombstone.
final class TombstoneFragment {
  /// Creates a fragment of [kind] showing [text].
  const TombstoneFragment(this.kind, this.text);

  /// What the text is.
  final TombstoneFragmentKind kind;

  /// The text to show.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is TombstoneFragment && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => 'TombstoneFragment($kind, $text)';
}
