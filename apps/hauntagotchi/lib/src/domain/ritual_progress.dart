/// How far the resurrection ritual has come: candles lit out of candles needed.
final class RitualProgress {
  /// Creates a progress value.
  const RitualProgress({required this.done, required this.needed});

  /// How many active habits were completed today.
  final int done;

  /// How many completed habits the ritual needs.
  final int needed;

  /// Whether enough habits were completed to resurrect the ghost.
  bool get isComplete => done >= needed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitualProgress && other.done == done && other.needed == needed;

  @override
  int get hashCode => Object.hash(done, needed);

  @override
  String toString() => 'RitualProgress($done/$needed)';
}
