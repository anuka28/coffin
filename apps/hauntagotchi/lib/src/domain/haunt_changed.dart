part of 'haunt_result.dart';

/// An action that was applied.
final class HauntChanged extends HauntResult {
  /// Creates a result carrying [next] and whether it [resurrected] the ghost.
  const HauntChanged(this.next, {this.resurrected = false});

  /// The haunting after the action.
  final Haunting next;

  /// Whether the action completed the resurrection ritual.
  final bool resurrected;
}
