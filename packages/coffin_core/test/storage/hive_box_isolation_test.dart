@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'support/hive_test_box.dart';

void main() {
  test('two boxes keep their own values, also after reopening one', () async {
    final a = await openHiveTestBox();
    final b = await openHiveTestBox();
    Box<dynamic>? reopened;
    try {
      expect(a.name, isNot(b.name));
      expect(a.directory.path, isNot(b.directory.path));

      // Each box lives in its own directory, so the files cannot overlap.
      expect(a.box.path, isNotNull);
      expect(b.box.path, isNotNull);
      expect(a.box.path!, startsWith(a.directory.path));
      expect(b.box.path!, startsWith(b.directory.path));
      expect(a.box.path, isNot(b.box.path));

      await a.box.put('shared', 'value-a');
      await b.box.put('shared', 'value-b');

      expect(a.box.get('shared'), 'value-a');
      expect(b.box.get('shared'), 'value-b');

      // Close first, then reopen with the same name and directory.
      await a.box.close();
      expect(a.box.isOpen, isFalse);
      expect(b.box.isOpen, isTrue);

      reopened = await Hive.openBox<dynamic>(a.name, path: a.directory.path);
      expect(reopened.path!, startsWith(a.directory.path));
      expect(reopened.path!, isNot(startsWith(b.directory.path)));

      expect(reopened.get('shared'), 'value-a');
      expect(b.box.get('shared'), 'value-b');
      expect(reopened.length, 1);
      expect(b.box.length, 1);
    } finally {
      // Close the reopened instance before its directory is deleted.
      if (reopened != null && reopened.isOpen) await reopened.close();
      await a.dispose();
      await b.dispose();
    }
  });
}
