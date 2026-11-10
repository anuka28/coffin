import 'dart:convert';

import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/json_safety.dart';
import 'package:flutter_test/flutter_test.dart'
    show equals, expect, group, isTrue, test;
import 'package:glados/glados.dart' hide equals, expect, group, isTrue, test;

import 'support/storage_generators.dart';
import 'support/test_note.dart';

// This file runs on the VM and on Chrome: no dart:io, no hive_ce, no
// @TestOn('vm'). It avoids any.intInRange and any.listWithLengthInRange,
// which throw on web in glados 1.1.7.

const int _numRuns = 200;
const TestNoteCodec _codec = TestNoteCodec();

/// How many times the property body ran.
int _runs = 0;

void main() {
  group('RecordCodec property: round trip', () {
    // Feature: crypt-storage, Property 1: codec round trip
    // Validates: Requirements 6.2, 6.4, 12.1
    Glados(anyTestNote, ExploreConfig(numRuns: _numRuns)).test(
      'decode(encode(x)) equals x and encode(x) is JSON-safe',
      (TestNote x) {
        _runs++;
        final JsonMap encoded = _codec.encode(x);
        expect(
          JsonSafety.isSafe(encoded),
          isTrue,
          reason: 'encode is not JSON-safe for $x -> $encoded',
        );
        expect(_codec.decode(encoded), equals(x), reason: 'direct, input $x');

        // The path the real store takes: through JSON text.
        final Object? parsed = jsonDecode(jsonEncode(encoded));
        final TestNote viaText = _codec.decode(
          Map<String, Object?>.from(parsed! as Map<Object?, Object?>),
        );
        expect(viaText, equals(x), reason: 'via JSON text, input $x');
      },
    );

    test('the property body ran $_numRuns times', () {
      expect(_runs, _numRuns);
    });
  });
}
