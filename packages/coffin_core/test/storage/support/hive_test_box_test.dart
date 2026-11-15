@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'hive_test_box.dart';

void main() {
  group('openHiveTestBox', () {
    test('names are unique and valid', () async {
      final boxes = <HiveTestBox>[];
      addTearDown(() async {
        for (final b in boxes) {
          await b.dispose();
        }
      });
      for (var i = 0; i < 20; i++) {
        boxes.add(await openHiveTestBox());
      }
      final names = boxes.map((b) => b.name).toList();
      expect(names.toSet().length, names.length);
      final valid = RegExp(r'^crypt_t\d+_[0-9a-f]{8}$');
      for (final n in names) {
        expect(n, matches(valid));
        expect(n.length, lessThanOrEqualTo(255));
      }
      final dirs = boxes.map((b) => b.directory.path).toSet();
      expect(dirs.length, boxes.length);
      for (final b in boxes) {
        expect(b.box.name, b.name);
        expect(b.directory.path, contains('crypt_storage_'));
      }
    });

    test('dispose closes the box, then removes the directory', () async {
      final helper = await openHiveTestBox();
      await helper.box.put('k', 'v');
      expect(helper.box.isOpen, isTrue);
      expect(helper.directory.existsSync(), isTrue);
      expect(helper.directory.listSync(), isNotEmpty);

      await helper.dispose();

      expect(helper.box.isOpen, isFalse);
      expect(helper.directory.existsSync(), isFalse);
    });

    test('a second dispose is safe', () async {
      final helper = await openHiveTestBox();
      await helper.dispose();
      await helper.dispose();
      expect(helper.directory.existsSync(), isFalse);
    });

    // The body fails inside the test, the failure is caught by
    // expectLater(throwsA), and the teardown registered with addTearDown
    // runs after this test ends. The next test proves the directory is gone.
    Directory? failedBodyDir;
    HiveTestBox? failedBodyHelper;

    test(
      'failing body: register addTearDown then fail (failure caught)',
      () async {
        Future<void> body() async {
          final helper = await openHiveTestBox();
          addTearDown(helper.dispose);
          failedBodyHelper = helper;
          failedBodyDir = helper.directory;
          await helper.box.put('k', 'v');
          throw StateError('simulated failure in test body');
        }

        await expectLater(body(), throwsA(isA<StateError>()));
        // Teardown has not run yet: the box is still open here.
        expect(failedBodyHelper!.box.isOpen, isTrue);
        expect(failedBodyDir!.existsSync(), isTrue);
      },
    );

    test('failing body: teardown closed the box and removed the directory', () {
      expect(failedBodyHelper, isNotNull, reason: 'previous test must run');
      expect(failedBodyHelper!.box.isOpen, isFalse);
      expect(failedBodyDir!.existsSync(), isFalse);
    });

    test('failing body with try/finally still cleans up', () async {
      final helper = await openHiveTestBox();
      Future<void> body() async {
        try {
          throw StateError('boom');
        } finally {
          await helper.dispose();
        }
      }

      await expectLater(body(), throwsA(isA<StateError>()));
      expect(helper.box.isOpen, isFalse);
      expect(helper.directory.existsSync(), isFalse);
    });
  });
}
