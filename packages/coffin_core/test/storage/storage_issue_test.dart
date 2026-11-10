import 'package:coffin_core/src/storage/storage_issue.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = StorageIssue(
    kind: StorageIssueKind.corruptRecord,
    key: 'a',
    message: 'm',
  );

  group('StorageIssue', () {
    test('exposes its fields, key is optional', () {
      expect(base.kind, StorageIssueKind.corruptRecord);
      expect(base.key, 'a');
      expect(base.message, 'm');
      const noKey = StorageIssue(
        kind: StorageIssueKind.fallbackToMemory,
        message: 'x',
      );
      expect(noKey.key, isNull);
    });

    test('equal issues share == and hashCode', () {
      const same = StorageIssue(
        kind: StorageIssueKind.corruptRecord,
        key: 'a',
        message: 'm',
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
    });

    test('differs per field in == and hashCode', () {
      const otherKind = StorageIssue(
        kind: StorageIssueKind.unknownVersion,
        key: 'a',
        message: 'm',
      );
      const otherKey = StorageIssue(
        kind: StorageIssueKind.corruptRecord,
        key: 'b',
        message: 'm',
      );
      const nullKey = StorageIssue(
        kind: StorageIssueKind.corruptRecord,
        message: 'm',
      );
      const otherMessage = StorageIssue(
        kind: StorageIssueKind.corruptRecord,
        key: 'a',
        message: 'n',
      );
      for (final other in [otherKind, otherKey, nullKey, otherMessage]) {
        expect(base, isNot(other));
        expect(base.hashCode, isNot(other.hashCode));
      }
    });

    test('is not equal to other types', () {
      expect(base == Object(), isFalse);
    });

    test('toString names kind, key and message', () {
      expect(base.toString(), contains('corruptRecord'));
      expect(base.toString(), contains('"a"'));
      expect(base.toString(), contains('"m"'));
    });
  });
}
