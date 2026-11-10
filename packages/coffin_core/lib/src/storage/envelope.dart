import 'package:meta/meta.dart';

import 'json_map.dart';

/// A stored wrapper: a schema version and its payload.
@immutable
final class Envelope {
  /// Creates an envelope holding [version] and [data].
  const Envelope(this.version, this.data);

  /// The schema version the [data] was written with.
  final int version;

  /// The payload.
  final JsonMap data;
}
