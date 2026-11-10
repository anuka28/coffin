import 'dart:convert';

import 'envelope.dart';
import 'envelope_format_exception.dart';
import 'json_map.dart';

/// Reads and writes the envelope text: `{"v":<int>,"data":{...}}`.
abstract final class EnvelopeCodec {
  /// Largest accepted schema version: 2^31 - 1.
  static const int maxVersion = 2147483647;

  /// The envelope text for [version] and [data].
  ///
  /// JSON-safety of [data] is the caller's concern (see the JsonSafety check).
  static String encode(int version, JsonMap data) =>
      jsonEncode(<String, Object?>{'v': version, 'data': data});

  /// Parses [raw].
  ///
  /// Throws [EnvelopeFormatException] with a fixed message (never part of the
  /// input) when the text is not a JSON object, `v` is missing, not a number,
  /// not integral, negative or above [maxVersion], or `data` is missing or not
  /// an object. Extra properties are ignored.
  static Envelope parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const EnvelopeFormatException('not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const EnvelopeFormatException('not a JSON object');
    }
    final Object? v = decoded['v'];
    // Integral check works for both int and double, so 2 and 2.0 agree on the
    // VM and on web.
    if (v is! num ||
        v.isNaN ||
        v < 0 ||
        v > maxVersion ||
        v != v.truncateToDouble()) {
      throw const EnvelopeFormatException('invalid version');
    }
    final Object? data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const EnvelopeFormatException('invalid data');
    }
    return Envelope(v.toInt(), data);
  }
}
