import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReplySource', () {
    test('offline is a const value named offline', () {
      const ReplySource s = ReplySource.offline;
      expect(s.name, 'offline');
      expect(identical(s, ReplySource.offline), isTrue);
      expect(ReplySource.maxNameLength, 32);
    });

    test('a custom source reusing offline equals the constant', () {
      expect(ReplySource('offline'), ReplySource.offline);
      expect(ReplySource('offline').hashCode, ReplySource.offline.hashCode);
    });

    test('remote is accepted and differs from offline', () {
      final ReplySource remote = ReplySource('remote');
      expect(remote.name, 'remote');
      expect(remote == ReplySource.offline, isFalse);
    });

    test('caps the name at 32 code units', () {
      expect(ReplySource('a' * 32).name, 'a' * 32);
      expect(() => ReplySource('a' * 33), throwsArgumentError);
    });

    test('rejects invalid names with ArgumentError', () {
      for (final String name in <String>[
        '',
        '1remote',
        'Remote',
        're mote',
        're-mote',
        'r\u00e9mote',
        'séance verdict',
      ]) {
        expect(() => ReplySource(name), throwsArgumentError, reason: name);
      }
    });

    test('error message never contains the rejected text', () {
      const String bad = 'Zq Wx-Yy';
      try {
        ReplySource(bad);
        fail('should throw');
      } on ArgumentError catch (e) {
        expect(e.toString().contains(bad), isFalse);
      }
    });

    test('toString is stable and readable', () {
      expect(ReplySource.offline.toString(), 'ReplySource(offline)');
      expect(ReplySource('remote').toString(), 'ReplySource(remote)');
    });
  });
}
