import 'ghost_state.dart';

/// What the voice needs to know about the home screen at one moment.
///
/// [state] is null while the home screen is not ready. [checkOffs] and
/// [resurrections] only ever rise, so comparing two snapshots shows what
/// happened between them.
final class VoiceSnapshot {
  /// Creates a snapshot.
  const VoiceSnapshot({
    required this.state,
    required this.checkOffs,
    required this.resurrections,
  });

  /// The ghost state, or null while the home screen is not ready.
  final GhostState? state;

  /// How many check-offs have succeeded so far.
  final int checkOffs;

  /// How many resurrections have happened so far.
  final int resurrections;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceSnapshot &&
          other.state == state &&
          other.checkOffs == checkOffs &&
          other.resurrections == resurrections;

  @override
  int get hashCode => Object.hash(state, checkOffs, resurrections);

  @override
  String toString() =>
      'VoiceSnapshot(state: $state, checkOffs: $checkOffs, '
      'resurrections: $resurrections)';
}
