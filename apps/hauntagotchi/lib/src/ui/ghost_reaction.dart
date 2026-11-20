import 'ghost_reaction_kind.dart';

/// One reaction event. A new [key] means a new event.
final class GhostReaction {
  /// Creates an event of [kind] with [key].
  const GhostReaction(this.kind, this.key);

  /// What happened.
  final GhostReactionKind kind;

  /// The event number in its controller, starting at 1.
  final int key;

  @override
  bool operator ==(Object other) =>
      other is GhostReaction && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => 'GhostReaction($kind, $key)';
}
