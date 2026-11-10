import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/record_codec.dart';

/// Structural equality for JSON-like values (maps, lists, scalars).
///
/// Numbers compare with `==`, so `1` equals `1.0`. That is on purpose: an
/// integral double can come back as an int after it passes through JSON text
/// (always on web, where both are the same JS number), and a round trip must
/// still count as exact.
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// A hash code that agrees with [deepEquals]: equal values hash equally.
int deepHash(Object? value) {
  if (value is Map) {
    // Order independent, like map equality.
    int sum = 0;
    for (final MapEntry<Object?, Object?> e in value.entries) {
      sum += Object.hash(e.key, deepHash(e.value));
    }
    return Object.hash('map', value.length, sum);
  }
  if (value is List) {
    return Object.hashAll(<int>[for (final Object? v in value) deepHash(v)]);
  }
  if (value is num) {
    // `1`, `1.0` and `-0.0` are equal under `==`, so they must hash alike.
    return value == 0 ? 0 : value.toDouble().hashCode;
  }
  return value.hashCode;
}

/// A small record used by the storage tests.
///
/// It has a scalar, a nullable double, a list and a nested map, so every kind
/// of JSON value is exercised. It lives in tests, not in `lib/`.
final class TestNote {
  /// Creates a note.
  const TestNote({
    required this.title,
    this.count = 0,
    this.weight,
    this.tags = const <String>[],
    this.extra = const <String, Object?>{},
  });

  /// Free text.
  final String title;

  /// A whole number.
  final int count;

  /// A fractional number, or null.
  final double? weight;

  /// A list of strings.
  final List<String> tags;

  /// A nested JSON-safe map.
  final Map<String, Object?> extra;

  @override
  bool operator ==(Object other) =>
      other is TestNote &&
      other.title == title &&
      other.count == count &&
      other.weight == weight &&
      deepEquals(other.tags, tags) &&
      deepEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    title,
    count,
    deepHash(weight),
    deepHash(tags),
    deepHash(extra),
  );

  /// Prints only the fields that carry information, for example
  /// `TestNote(title: x, count: 2)`.
  @override
  String toString() {
    final List<String> parts = <String>['title: $title', 'count: $count'];
    if (weight != null) parts.add('weight: $weight');
    if (tags.isNotEmpty) parts.add('tags: $tags');
    if (extra.isNotEmpty) parts.add('extra: $extra');
    return 'TestNote(${parts.join(', ')})';
  }
}

/// Codec for [TestNote].
///
/// Web note: an integral double such as `3.0` becomes the int `3` once it has
/// been through JSON text (always on web, where ints and doubles are the same
/// JS number, and possibly on other platforms). [decode] therefore converts
/// with `(json['weight'] as num).toDouble()` so the record always gets a
/// double back, and `==` then compares equal on every platform.
final class TestNoteCodec implements RecordCodec<TestNote> {
  /// Creates the codec.
  const TestNoteCodec();

  @override
  JsonMap encode(TestNote record) => <String, Object?>{
    'title': record.title,
    'count': record.count,
    'weight': record.weight,
    'tags': List<String>.of(record.tags),
    'extra': _copyJson(record.extra),
  };

  /// Strict on purpose: a wrong type throws, which the repositories report as
  /// a corrupt record.
  @override
  TestNote decode(JsonMap json) {
    final Object? rawWeight = json['weight'];
    return TestNote(
      title: json['title'] as String,
      count: (json['count'] as num).toInt(),
      weight: rawWeight == null ? null : (rawWeight as num).toDouble(),
      tags: List<String>.from(json['tags'] as List<Object?>),
      extra: _copyJson(
        json['extra'] as Map<Object?, Object?>,
      ) as Map<String, Object?>,
    );
  }
}

Object? _copyJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> e in value.entries)
        e.key! as String: _copyJson(e.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final Object? v in value) _copyJson(v)];
  }
  return value;
}
