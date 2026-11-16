import 'package:meta/meta.dart';

import 'identifier_rules.dart';

/// Where a reply came from.
///
/// An open value type, so a new source needs no change to other files.
/// Equality is on [name] only.
@immutable
final class ReplySource {
  /// Creates a source with a custom [name]. Same rules as an `AiPurpose` id,
  /// but at most [maxNameLength] code units. Throws [ArgumentError]
  /// otherwise.
  factory ReplySource(String name) {
    final String? problem = IdentifierRules.violation(
      name,
      maxLength: maxNameLength,
    );
    if (problem != null) {
      throw ArgumentError.value(name.length, 'name.length', problem);
    }
    return ReplySource._(name);
  }

  const ReplySource._(this.name);

  /// Text produced by the offline generator.
  static const ReplySource offline = ReplySource._('offline');

  /// Longest allowed name, in UTF-16 code units.
  static const int maxNameLength = 32;

  /// Stable, human-readable name used by tests and logs.
  final String name;

  @override
  bool operator ==(Object other) => other is ReplySource && other.name == name;

  @override
  int get hashCode => Object.hash(ReplySource, name);

  @override
  String toString() => 'ReplySource($name)';
}
