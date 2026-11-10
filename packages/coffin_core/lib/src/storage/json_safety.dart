import 'json_map.dart';

/// Checks and copies JSON-safe values.
///
/// A value is JSON-safe when it is null, a bool, a finite number (integers
/// within +/-[maxSafeInt]), a String, a List of safe values, or a Map with
/// String keys and safe values. Nesting is limited to [maxDepth] levels, which
/// also rejects cyclic structures.
///
/// Web note: on the web every `int` is a JavaScript double, so an integral
/// double such as `1e20` is an `int` and is rejected by the magnitude check,
/// and a value like `2^53 + 1` cannot exist at all. The limits below are
/// written as plain comparisons that behave the same on the VM and the web.
abstract final class JsonSafety {
  /// Largest integer magnitude kept exactly on VM and web: 2^53 - 1.
  static const int maxSafeInt = 9007199254740991;

  /// Maximum nesting depth. Deeper (or cyclic) values are unsafe.
  ///
  /// The top-level map is depth 1 and each nested list or map adds one, so a
  /// map nested 64 levels is safe and one nested 65 levels is not.
  static const int maxDepth = 64;

  /// True when [value] is null, bool, finite num (ints within +/-[maxSafeInt]),
  /// String, List of safe values, or `Map<String, _>` of safe values.
  static bool isSafe(Object? value) => _violation(value, r'$', 0) == null;

  /// Throws [ArgumentError] (naming the path, never the value) when unsafe.
  ///
  /// Paths look like `$.name`, `$.tags[2]` or `$.a.b[0].c`, where `$` is [map].
  static void check(JsonMap map) {
    final problem = _violation(map, r'$', 0);
    if (problem != null) {
      throw ArgumentError(
        'not JSON-safe at ${problem.path}: ${problem.reason}',
      );
    }
  }

  /// A deep copy with fresh `Map<String, Object?>` and `List<Object?>`
  /// instances.
  ///
  /// Throws [ArgumentError] (as [check] does) when [map] is not JSON-safe.
  static JsonMap deepCopy(JsonMap map) {
    check(map);
    return _copyMap(map);
  }

  static JsonMap _copyMap(Map<Object?, Object?> source) {
    final copy = <String, Object?>{};
    source.forEach((key, value) {
      copy[key! as String] = _copy(value);
    });
    return copy;
  }

  static Object? _copy(Object? value) {
    if (value is Map) return _copyMap(value);
    if (value is List) {
      return <Object?>[for (final item in value) _copy(item)];
    }
    return value;
  }

  /// The first violation found under [value], or null when it is safe.
  ///
  /// [depth] is the number of containers already entered above [value].
  static ({String path, String reason})? _violation(
    Object? value,
    String path,
    int depth,
  ) {
    if (value == null || value is bool || value is String) return null;
    if (value is int) {
      // Compare both sides instead of using abs(): int.minValue.abs() overflows
      // on the VM.
      if (value > maxSafeInt || value < -maxSafeInt) {
        return (path: path, reason: 'integer beyond +/-(2^53 - 1)');
      }
      return null;
    }
    if (value is double) {
      if (value.isNaN) return (path: path, reason: 'NaN');
      if (value.isInfinite) return (path: path, reason: 'infinite number');
      return null;
    }
    if (value is Map) {
      if (depth + 1 > maxDepth) {
        return (path: path, reason: 'nested deeper than $maxDepth (or cyclic)');
      }
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          return (path: path, reason: 'map key is not a String');
        }
        final problem = _violation(entry.value, '$path.$key', depth + 1);
        if (problem != null) return problem;
      }
      return null;
    }
    if (value is List) {
      if (depth + 1 > maxDepth) {
        return (path: path, reason: 'nested deeper than $maxDepth (or cyclic)');
      }
      for (var i = 0; i < value.length; i++) {
        final problem = _violation(value[i], '$path[$i]', depth + 1);
        if (problem != null) return problem;
      }
      return null;
    }
    return (path: path, reason: 'unsupported type ${value.runtimeType}');
  }
}
