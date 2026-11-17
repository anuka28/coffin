import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fnv_hash.dart';
import 'temp_root.dart';

void main() {
  group('tempRoot', () {
    Directory? created;

    test('creates an existing directory and registers cleanup', () {
      final dir = tempRoot();
      created = dir;
      expect(dir.existsSync(), isTrue);
    });

    test('previous temp dir was deleted after its test', () {
      expect(created, isNotNull);
      expect(created!.existsSync(), isFalse);
    });

    test('returns unique directories', () {
      expect(tempRoot().path, isNot(tempRoot().path));
    });
  });

  group('fnv1a64', () {
    test('matches known vectors', () {
      expect(fnv1a64(const []), 0xcbf29ce484222325);
      expect(fnv1a64(utf8.encode('a')), 0xaf63dc4c8601ec8c);
      expect(fnv1a64(utf8.encode('foobar')), 0x85944171f73967e8);
    });
  });
}
