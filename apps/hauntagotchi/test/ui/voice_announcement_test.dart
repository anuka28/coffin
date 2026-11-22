import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/voice_announcement.dart';

void main() {
  group('VoiceAnnouncement', () {
    test('equal key and text are equal with the same hashCode', () {
      const a = VoiceAnnouncement(key: 1, text: 'Boo.');
      const b = VoiceAnnouncement(key: 1, text: 'Boo.');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different key or text is not equal', () {
      const a = VoiceAnnouncement(key: 1, text: 'Boo.');
      expect(a, isNot(const VoiceAnnouncement(key: 2, text: 'Boo.')));
      expect(a, isNot(const VoiceAnnouncement(key: 1, text: 'Hi.')));
    });

    test('toString shows key and text', () {
      const a = VoiceAnnouncement(key: 3, text: 'Hi');
      expect(a.toString(), contains('3'));
      expect(a.toString(), contains('Hi'));
    });
  });
}
