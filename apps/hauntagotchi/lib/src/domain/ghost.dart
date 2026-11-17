import 'balance.dart';
import 'local_day.dart';

/// The user's ghost. Immutable; changes produce a new value.
final class Ghost {
  /// Creates a ghost.
  const Ghost({
    required this.name,
    required this.health,
    required this.lastSettledDay,
    this.resurrectionCount = 0,
  });

  /// Creates a new ghost named [Balance.defaultGhostName] with full Health,
  /// settled up to the day before [today].
  Ghost.fresh(LocalDay today)
    : name = Balance.defaultGhostName,
      health = Balance.maxHealth,
      lastSettledDay = today.previous,
      resurrectionCount = 0;

  /// The ghost's name.
  final String name;

  /// The ghost's Health, 0..100.
  final int health;

  /// The last day whose habits have been counted into [health].
  final LocalDay lastSettledDay;

  /// How many times the ghost has been resurrected.
  final int resurrectionCount;

  /// Whether the ghost has no Health left.
  bool get isDead => health == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ghost &&
          other.name == name &&
          other.health == health &&
          other.lastSettledDay == lastSettledDay &&
          other.resurrectionCount == resurrectionCount;

  @override
  int get hashCode =>
      Object.hash(name, health, lastSettledDay, resurrectionCount);

  @override
  String toString() =>
      'Ghost($name, health: $health, settled: $lastSettledDay, '
      'resurrections: $resurrectionCount)';
}
