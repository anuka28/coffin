// VM only: rootBundle never completes in Flutter's Chrome test runner
// (flutter/flutter#96123), so the font load would hang. This test measures
// the same Creepster TTF the web build uses, and the footprint model keeps
// about 7% margin on every metric, so the VM result also covers web.
@TestOn('vm')
library;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/epitaph_footprint.dart';
import 'package:graveyard/src/domain/scene/arch_fit.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';

const List<String> _texts = ['R.I.P.', 'RISEN'];

/// Loads the real Creepster font so the tests measure it and not the
/// fallback test font.
Future<void> _loadCreepster() async {
  final loader = FontLoader('packages/coffin_core/Creepster')
    ..addFont(
      rootBundle.load(
        'packages/coffin_core/assets/fonts/Creepster-Regular.ttf',
      ),
    );
  await loader.load();
}

Size _measure(String text, double fontSize) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: CoffinTypography.displayFamily,
        package: CoffinTypography.package,
        fontSize: fontSize,
        letterSpacing: ArchEpitaph.letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    maxLines: 1,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadCreepster();
  });

  test('Creepster is really loaded (not the fallback font)', () {
    // The fallback test font is about 20 px per 20 px font for "RISEN"
    // (5 glyphs at 20 px = 100 px); Creepster is about 2.1 px per font px.
    final risen = _measure('RISEN', 20);
    expect(
      risen.width,
      lessThan(60),
      reason: 'RISEN at 20 px measured ${risen.width}: font did not load',
    );
  });

  test('model constants equal the ArchEpitaph constants', () {
    expect(EpitaphFootprint.archRise, ArchEpitaph.archRise);
    expect(EpitaphFootprint.baseFontSize, ArchEpitaph.baseFontSize);
    expect(EpitaphFootprint.letterSpacing, ArchEpitaph.letterSpacing);
  });

  test('the model covers the real rectangles of both texts', () {
    for (var width = 120.0; width <= 400; width += 20) {
      for (var scale = 1.0; scale <= 2.0; scale += 0.25) {
        final KeepOutRect model = EpitaphFootprint.forStone(
          stoneWidth: width,
          textScale: scale,
        );
        for (final text in _texts) {
          final KeepOutRect real = ArchEpitaph.rectFor(
            width: width,
            textScaler: TextScaler.linear(scale),
            text: text,
          );
          final reason =
              '"$text" at width $width, scale $scale: '
              'model $model, real $real';
          expect(model.left, lessThanOrEqualTo(real.left), reason: reason);
          expect(model.top, lessThanOrEqualTo(real.top), reason: reason);
          expect(model.right, greaterThanOrEqualTo(real.right), reason: reason);
          expect(
            model.bottom,
            greaterThanOrEqualTo(real.bottom),
            reason: reason,
          );
        }
      }
    }
  });

  test(
    'with the measured metrics the model places the line like the widget',
    () {
      for (final text in _texts) {
        for (var width = 120.0; width <= 400; width += 20) {
          for (var scale = 1.0; scale <= 2.0; scale += 0.25) {
            final scaledBase = ArchEpitaph.baseFontSize * scale;
            final measured = _measure(text, scaledBase);
            // The way ArchEpitaph._layout does it, with the measured numbers.
            final fit = ArchFit.positionFor(
              archWidth: width,
              archRise: ArchEpitaph.archRise,
              lineHeight: measured.height,
              textWidth: measured.width,
              fontSize: scaledBase,
            );
            final real = ArchEpitaph.rectFor(
              width: width,
              textScaler: TextScaler.linear(scale),
              text: text,
            );
            final reason = '"$text" at width $width, scale $scale';
            expect(fit.top, real.top, reason: reason);
            final ratio = measured.height / scaledBase;
            expect(
              real.bottom - real.top,
              closeTo(ratio * fit.fontSize, 0.5),
              reason: reason,
            );
          }
        }
      }
    },
  );
}
