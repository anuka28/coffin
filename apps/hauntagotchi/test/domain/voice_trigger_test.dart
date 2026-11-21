import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';

void main() {
  group('VoiceTrigger', () {
    test('has the four values in this order', () {
      expect(VoiceTrigger.values, <VoiceTrigger>[
        VoiceTrigger.appOpened,
        VoiceTrigger.checkedOff,
        VoiceTrigger.moodChanged,
        VoiceTrigger.resurrected,
      ]);
    });

    test('names are exactly the contract with coffin_core', () {
      expect(VoiceTrigger.appOpened.name, 'appOpened');
      expect(VoiceTrigger.checkedOff.name, 'checkedOff');
      expect(VoiceTrigger.moodChanged.name, 'moodChanged');
      expect(VoiceTrigger.resurrected.name, 'resurrected');
    });

    test('names equal the event names coffin_core accepts', () {
      const accepted = <String>[
        'appOpened',
        'checkedOff',
        'moodChanged',
        'resurrected',
      ];
      expect(VoiceTrigger.values.map((t) => t.name).toList(), accepted);
    });
  });
}
