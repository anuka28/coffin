import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/envelope_format_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const max = EnvelopeCodec.maxVersion;

  void rejects(String raw) {
    expect(
      () => EnvelopeCodec.parse(raw),
      throwsA(isA<EnvelopeFormatException>()),
      reason: raw,
    );
  }

  group('EnvelopeCodec.encode', () {
    test('writes the exact text', () {
      expect(
        EnvelopeCodec.encode(3, <String, Object?>{
          'a': 1,
          'b': <Object?>['x', null, true],
        }),
        '{"v":3,"data":{"a":1,"b":["x",null,true]}}',
      );
    });

    test('round trips through parse', () {
      final env = EnvelopeCodec.parse(
        EnvelopeCodec.encode(7, <String, Object?>{'k': 'v'}),
      );
      expect(env.version, 7);
      expect(env.data, <String, Object?>{'k': 'v'});
    });
  });

  group('EnvelopeCodec.parse', () {
    test('rejects text that is not JSON or not an object', () {
      for (final raw in ['', 'nope', '{', '[]', '1', '"s"', 'null']) {
        rejects(raw);
      }
    });

    test('rejects a bad v', () {
      for (final v in ['1.5', '-1', '"1"', 'null', 'true', '[]', '{}']) {
        rejects('{"v":$v,"data":{}}');
      }
      rejects('{"data":{}}');
    });

    test('rejects a bad data', () {
      for (final d in ['null', '1', '"s"', '[]', 'true']) {
        rejects('{"v":1,"data":$d}');
      }
      rejects('{"v":1}');
    });

    test('accepts 2.0 as version 2', () {
      expect(EnvelopeCodec.parse('{"v":2.0,"data":{}}').version, 2);
    });

    test('accepts 0 and maxVersion, rejects maxVersion + 1', () {
      expect(EnvelopeCodec.parse('{"v":0,"data":{}}').version, 0);
      expect(EnvelopeCodec.parse('{"v":$max,"data":{}}').version, max);
      rejects('{"v":${max + 1},"data":{}}');
      rejects('{"v":1e999,"data":{}}');
    });

    test('ignores extra properties', () {
      final env = EnvelopeCodec.parse(
        '{"x":[1],"v":1,"data":{"a":2},"y":null}',
      );
      expect(env.version, 1);
      expect(env.data, <String, Object?>{'a': 2});
    });

    test('messages never contain the input text', () {
      const secret = 'SECRET_PAYLOAD';
      final inputs = [
        'not json $secret',
        '{"$secret":',
        '["$secret"]',
        '{"v":"$secret","data":{}}',
        '{"v":1.5,"$secret":1,"data":{}}',
        '{"v":1,"data":"$secret"}',
      ];
      for (final raw in inputs) {
        try {
          EnvelopeCodec.parse(raw);
          fail('expected a throw for $raw');
        } on EnvelopeFormatException catch (e) {
          expect(e.message, isNot(contains(secret)));
          expect(e.toString(), isNot(contains(secret)));
          expect(e.source, isNull);
        }
      }
    });
  });
}
