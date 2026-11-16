import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_reply.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/reply_source.dart';
import 'package:flutter_test/flutter_test.dart';

AiRequest _request(int maxLength) =>
    AiRequest(purpose: AiPurpose.ghostMoodLine, maxLength: maxLength);

AiReply _reply(String text) => AiReply(text: text, source: ReplySource.offline);

void main() {
  group('construction', () {
    test('accepts empty, whitespace-only and very long text', () {
      expect(() => _reply(''), returnsNormally);
      expect(() => _reply(' \n\t'), returnsNormally);
      expect(_reply('x' * 100000).text.length, 100000);
    });

    test('can be const', () {
      const a = AiReply(text: 'boo', source: ReplySource.offline);
      const b = AiReply(text: 'boo', source: ReplySource.offline);
      expect(identical(a, b), isTrue);
    });
  });

  group('equality', () {
    test('equal when text and source match', () {
      final a = AiReply(text: 'boo', source: ReplySource('remote'));
      final b = AiReply(text: 'boo', source: ReplySource('remote'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('text changes equality', () {
      expect(_reply('boo'), isNot(_reply('boo!')));
    });

    test('source changes equality', () {
      final other = AiReply(text: 'boo', source: ReplySource('remote'));
      expect(_reply('boo'), isNot(other));
    });
  });

  group('isUsableFor', () {
    test('empty text is not usable', () {
      expect(_reply('').isUsableFor(_request(16)), isFalse);
    });

    test('whitespace-only text is not usable', () {
      for (final text in <String>[
        ' ',
        '\n\t',
        '\u00A0',
        '\u3000',
        ' \u00A0\u3000 ',
      ]) {
        expect(_reply(text).isUsableFor(_request(16)), isFalse, reason: text);
      }
    });

    test('text of exactly maxLength is usable', () {
      expect(_reply('a' * 16).isUsableFor(_request(16)), isTrue);
    });

    test('text of maxLength + 1 is not usable', () {
      expect(_reply('a' * 17).isUsableFor(_request(16)), isFalse);
    });
  });

  test('toString has the source and length but not the text', () {
    final text = _reply('Mortimer the ghost').toString();
    expect(text, contains('offline'));
    expect(text, contains('18'));
    expect(text, isNot(contains('Mortimer')));
  });
}
