import 'package:meta/meta.dart';

import 'ai_purpose.dart';

/// A question for a text generator: what the text is for, the facts it may
/// use, how long it may be and a seed for repeatable output.
///
/// Equality compares all four fields. Facts compare as a set of key and value
/// pairs, so insertion order does not matter.
@immutable
final class AiRequest {
  /// Creates a request. Throws [ArgumentError] when [maxLength] is below
  /// [minimumMaxLength] or [seed] is outside 0 to [maxSeed]. Odd [facts] are
  /// accepted.
  AiRequest({
    required this.purpose,
    Map<String, Object?> facts = const <String, Object?>{},
    required this.maxLength,
    this.seed = 0,
  }) : facts = Map<String, Object?>.unmodifiable(facts) {
    if (maxLength < minimumMaxLength) {
      throw ArgumentError.value(
        maxLength,
        'maxLength',
        'must be at least $minimumMaxLength',
      );
    }
    if (seed < 0 || seed > maxSeed) {
      throw ArgumentError.value(
        seed,
        'seed',
        'must be in the range 0 to $maxSeed',
      );
    }
  }

  /// Smallest accepted [maxLength]: 16 UTF-16 code units.
  static const int minimumMaxLength = 16;

  /// Largest accepted [seed]: 4294967295.
  static const int maxSeed = 4294967295;

  /// What the text is for.
  final AiPurpose purpose;

  /// Facts the text may use. An unmodifiable copy of the map given.
  final Map<String, Object?> facts;

  /// Longest allowed reply, in UTF-16 code units.
  final int maxLength;

  /// Seed for repeatable output, from 0 to [maxSeed].
  final int seed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiRequest ||
        other.purpose != purpose ||
        other.maxLength != maxLength ||
        other.seed != seed ||
        other.facts.length != facts.length) {
      return false;
    }
    for (final MapEntry<String, Object?> entry in facts.entries) {
      if (!other.facts.containsKey(entry.key)) return false;
      if (!_sameValue(entry.value, other.facts[entry.key])) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int combined = 0;
    for (final MapEntry<String, Object?> entry in facts.entries) {
      combined ^= Object.hash(entry.key, _valueHash(entry.value));
    }
    return Object.hash(AiRequest, purpose, maxLength, seed, combined);
  }

  @override
  String toString() =>
      'AiRequest(purpose: ${purpose.id}, facts: ${facts.length}, '
      'maxLength: $maxLength, seed: $seed)';

  /// Equal by `==`, or both NaN so that a request holding NaN equals itself.
  static bool _sameValue(Object? a, Object? b) {
    if (a == b) return true;
    return a is num && b is num && a.isNaN && b.isNaN;
  }

  /// A hash that agrees with [_sameValue]. Numbers that are equal must hash
  /// alike on the VM and on web, where an int and a whole double can differ.
  static int _valueHash(Object? value) {
    if (value is num) {
      if (value.isNaN) return 0;
      if (value is double &&
          value.isFinite &&
          value == value.truncateToDouble() &&
          value.abs() < _twoPow63) {
        // Whole doubles hash as the int they equal. This also folds -0.0 to 0.
        return value.toInt().hashCode;
      }
    }
    return value.hashCode;
  }

  static const double _twoPow63 = 9223372036854775808.0;
}
