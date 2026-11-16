import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_spooky.dart';

void main() {
  group('pumpSpooky', () {
    testWidgets('applies width, height, text scale and reduced motion', (
      tester,
    ) async {
      late BuildContext inner;
      await pumpSpooky(
        tester,
        Builder(
          builder: (context) {
            inner = context;
            return const SizedBox.expand();
          },
        ),
        width: 320,
        height: 640,
        textScale: 1.5,
        reducedMotion: true,
      );

      final MediaQueryData data = MediaQuery.of(inner);
      expect(data.size, const Size(320, 640));
      expect(data.textScaler.scale(10), 15);
      expect(data.disableAnimations, isTrue);
    });

    testWidgets('defaults to 360 wide, scale 1 and motion enabled', (
      tester,
    ) async {
      late BuildContext inner;
      await pumpSpooky(
        tester,
        Builder(
          builder: (context) {
            inner = context;
            return const SizedBox.expand();
          },
        ),
      );

      final MediaQueryData data = MediaQuery.of(inner);
      expect(data.size.width, 360);
      expect(data.textScaler.scale(10), 10);
      expect(data.disableAnimations, isFalse);
    });

    for (final Brightness brightness in Brightness.values) {
      testWidgets('uses the ${brightness.name} theme when asked', (
        tester,
      ) async {
        late BuildContext inner;
        await pumpSpooky(
          tester,
          Builder(
            builder: (context) {
              inner = context;
              return const SizedBox.expand();
            },
          ),
          brightness: brightness,
        );
        expect(Theme.of(inner).brightness, brightness);
      });
    }

    testWidgets('defaults to the dark theme', (tester) async {
      late BuildContext inner;
      await pumpSpooky(
        tester,
        Builder(
          builder: (context) {
            inner = context;
            return const SizedBox.expand();
          },
        ),
      );
      expect(Theme.of(inner).brightness, Brightness.dark);
    });

    test('exposes the standard widths and text scales', () {
      expect(testWidths, [320, 360, 1280]);
      expect(testTextScales, [1.0, 1.5]);
    });
  });
}
