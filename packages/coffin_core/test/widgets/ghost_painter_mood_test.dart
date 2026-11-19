import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:coffin_core/src/widgets/spooky_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Img {
  _Img(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final Uint8List bytes;

  int alpha(int x, int y) => bytes[(y * width + x) * 4 + 3];

  int argb(int x, int y) {
    final int i = (y * width + x) * 4;
    return (bytes[i + 3] << 24) |
        (bytes[i] << 16) |
        (bytes[i + 1] << 8) |
        bytes[i + 2];
  }
}

/// Paints [painter] into a box of [boxW] by [boxH], placed [margin] pixels
/// inside an in-memory image, and returns the raw pixels.
Future<_Img> _render(
  WidgetTester tester,
  GhostPainter painter,
  double boxW,
  double boxH, {
  int margin = 0,
  Color? background,
}) async {
  final int w = boxW.ceil() + 2 * margin;
  final int h = boxH.ceil() + 2 * margin;
  final _Img? img = await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    if (background != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = background,
      );
    }
    canvas.translate(margin.toDouble(), margin.toDouble());
    painter.paint(canvas, Size(boxW, boxH));
    final ui.Image image = await recorder.endRecording().toImage(w, h);
    final ByteData? data = await image.toByteData();
    image.dispose();
    return _Img(w, h, data!.buffer.asUint8List());
  });
  return img!;
}

bool _same(_Img a, _Img b) {
  if (a.bytes.length != b.bytes.length) {
    return false;
  }
  for (int i = 0; i < a.bytes.length; i++) {
    if (a.bytes[i] != b.bytes[i]) {
      return false;
    }
  }
  return true;
}

GhostPainter _legacy({double bob = 0, double headroom = 0}) => GhostPainter(
  bodyColor: const Color(0xFFFFFFFF),
  eyeColor: const Color(0xFF000000),
  bobOffset: bob,
  headroom: headroom,
);

GhostPainter _forSet(
  CoffinColorTokens set, {
  GhostMood? mood,
  MoodPose? pose,
  double bob = 0,
  double headroom = 0,
  bool glow = true,
}) {
  return GhostPainter(
    bodyColor: SpookyTokens.ghostBody(set),
    eyeColor: set.background,
    glow: glow
        ? <BoxShadow>[BoxShadow(color: set.primary, blurRadius: 12)]
        : const <BoxShadow>[],
    bobOffset: bob,
    headroom: headroom,
    mood: mood,
    pose: pose,
  );
}

void main() {
  group('GhostPainter mood: shouldRepaint', () {
    GhostPainter make({GhostMood? mood, MoodPose? pose}) => GhostPainter(
      bodyColor: const Color(0xFFFFFFFF),
      eyeColor: const Color(0xFF000000),
      mood: mood,
      pose: pose,
    );

    test('is false for equal inputs', () {
      expect(
        make(mood: GhostMood.hungry)
            .shouldRepaint(make(mood: GhostMood.hungry)),
        isFalse,
      );
      expect(
        make(pose: MoodPose.rest(GhostMood.fed))
            .shouldRepaint(make(pose: MoodPose.rest(GhostMood.fed))),
        isFalse,
      );
    });

    test('is true for a changed mood or pose', () {
      expect(
        make(mood: GhostMood.hungry)
            .shouldRepaint(make(mood: GhostMood.fading)),
        isTrue,
      );
      expect(make(mood: GhostMood.hungry).shouldRepaint(make()), isTrue);
      expect(
        make(pose: MoodPose.rest(GhostMood.fed)).shouldRepaint(
          make(pose: MoodPose.rest(GhostMood.fed).copyWith(scale: 1.05)),
        ),
        isTrue,
      );
    });

    test('pose wins over mood', () {
      expect(
        make(
          mood: GhostMood.dead,
          pose: MoodPose.rest(GhostMood.fed),
        ).shouldRepaint(
          make(mood: GhostMood.thriving, pose: MoodPose.rest(GhostMood.fed)),
        ),
        isTrue,
        reason: 'the mood field is still compared',
      );
    });
  });

  testWidgets('null mood and pose render the legacy bytes', (tester) async {
    final _Img a = await _render(tester, _legacy(bob: 3, headroom: 6), 80, 100);
    final _Img b = await _render(
      tester,
      const GhostPainter(
        bodyColor: Color(0xFFFFFFFF),
        eyeColor: Color(0xFF000000),
        bobOffset: 3,
        headroom: 6,
      ),
      80,
      100,
    );
    expect(_same(a, b), isTrue);
    expect(a.bytes.any((int v) => v != 0), isTrue);
  });

  for (final CoffinColorTokens set in CoffinColorTokens.variants) {
    testWidgets('every mood renders different bytes (${set.name})', (
      tester,
    ) async {
      const double size = 96;
      final int reserve = MoodTraits.reserveFor(size);
      final double boxH = size + 2 * reserve;
      final Map<GhostMood, _Img> full = <GhostMood, _Img>{};
      final Map<GhostMood, _Img> shape = <GhostMood, _Img>{};
      for (final GhostMood m in GhostMood.values) {
        full[m] = await _render(
          tester,
          _forSet(set, mood: m, headroom: reserve.toDouble()),
          size,
          boxH,
        );
        shape[m] = await _render(
          tester,
          _forSet(
            set,
            pose: MoodPose.rest(m).copyWith(opacity: 1),
            bob: 5,
            headroom: reserve.toDouble(),
          ),
          size,
          boxH,
        );
      }
      for (int i = 0; i < GhostMood.values.length; i++) {
        for (int j = i + 1; j < GhostMood.values.length; j++) {
          final GhostMood a = GhostMood.values[i];
          final GhostMood b = GhostMood.values[j];
          expect(_same(full[a]!, full[b]!), isFalse, reason: '$a vs $b');
          expect(
            _same(shape[a]!, shape[b]!),
            isFalse,
            reason: '$a vs $b with equal opacity and bob',
          );
        }
      }
    });
  }

  testWidgets('opacity lowers body and glow alpha, not the face', (
    tester,
  ) async {
    debugDisableShadows = false;
    const double size = 96;
    final int reserve = MoodTraits.reserveFor(size);
    const int margin = 30;
    final double boxH = size + 2 * reserve;
    const Color eye = Color(0xFF102030);
    GhostPainter make(double opacity, {bool glow = true}) => GhostPainter(
      bodyColor: const Color(0xFFFFFFFF),
      eyeColor: eye,
      glow: glow
          ? const <BoxShadow>[
              BoxShadow(color: Color(0xFFFF00FF), blurRadius: 10),
            ]
          : const <BoxShadow>[],
      headroom: reserve.toDouble(),
      pose: MoodPose.rest(GhostMood.thriving).copyWith(opacity: opacity),
    );
    final _Img full = await _render(
      tester,
      make(1),
      size,
      boxH,
      margin: margin,
    );
    final _Img faded = await _render(
      tester,
      make(0.5),
      size,
      boxH,
      margin: margin,
    );
    debugDisableShadows = true;
    const double w = 0.8 * size;
    final double cx = margin + size / 2;
    final double top = margin + reserve.toDouble();
    // Inside the body, away from the face.
    final int bx = (cx - 0.3 * w).round();
    final int by = (top + 0.6 * w).round();
    final _Img bodyOnly = await _render(
      tester,
      make(0.5, glow: false),
      size,
      boxH,
      margin: margin,
    );
    expect(full.alpha(bx, by), 255);
    expect(bodyOnly.alpha(bx, by), inInclusiveRange(126, 130));
    // Just outside the left edge: only glow.
    final int gx = (cx - w / 2 - 3).round();
    final int gy = (top + 0.5 * w).round();
    expect(faded.alpha(gx, gy), lessThan(full.alpha(gx, gy)));
    expect(full.alpha(gx, gy), greaterThan(0));
    // Eye center: full eye color in both.
    final int ex = (cx - 0.18 * w).round();
    final int ey = (top + 0.40 * w).round();
    expect(full.argb(ex, ey), eye.toARGB32());
    expect(faded.argb(ex, ey), eye.toARGB32());
  });

  group('worst poses stay inside the reserved box', () {
    final Map<String, MoodPose> poses = <String, MoodPose>{
      'rising at lift peak': MoodPose.rest(GhostMood.rising)
          .copyWith(lift: MoodTraits.risingMaxLift),
      'fed at pop peak': MoodPose.rest(GhostMood.fed)
          .copyWith(scale: MoodTraits.fedMaxScale, lift: MoodTraits.fedMaxLift),
      'dead tilt': MoodPose.rest(GhostMood.dead),
    };
    for (final double size in <double>[24, 96, 256]) {
      for (final MapEntry<String, MoodPose> entry in poses.entries) {
        for (final double bob in <double>[-8, 8]) {
          testWidgets('${entry.key}, size $size, bob $bob', (tester) async {
            final int reserve = MoodTraits.reserveFor(size);
            const int margin = 16;
            final double boxH = size + 2 * reserve;
            final _Img img = await _render(
              tester,
              _forSet(
                CoffinColorTokens.night,
                pose: entry.value,
                bob: bob,
                headroom: reserve.toDouble(),
                glow: false,
              ),
              size,
              boxH,
              margin: margin,
            );
            final int x0 = margin;
            final int x1 = margin + size.ceil();
            final int y0 = margin;
            final int y1 = margin + boxH.ceil();
            int firstRow = -1;
            int lastRow = -1;
            for (int y = 0; y < img.height; y++) {
              for (int x = 0; x < img.width; x++) {
                if (img.alpha(x, y) > 0) {
                  expect(
                    x >= x0 && x < x1 && y >= y0 && y < y1,
                    isTrue,
                    reason: 'pixel ($x, $y) outside [$x0,$x1) x [$y0,$y1)',
                  );
                  firstRow = firstRow < 0 ? y : firstRow;
                  lastRow = y;
                }
              }
            }
            expect(firstRow, greaterThanOrEqualTo(y0));
            expect(lastRow, lessThan(y1));
          });
        }
      }
    }
  });

  testWidgets('NaN and out-of-range pose numbers do not throw', (tester) async {
    const double nan = double.nan;
    const double inf = double.infinity;
    final List<MoodPose> poses = <MoodPose>[
      MoodPose(
        weights: List<double>.filled(7, nan),
        opacity: nan,
        lean: nan,
        droop: nan,
        scale: nan,
        lift: nan,
        bobAmplitude: nan,
      ),
      MoodPose(
        weights: <double>[-1, 5, inf, -inf, 0.5, 0, 0.001],
        opacity: 7,
        lean: inf,
        droop: -inf,
        scale: 99,
        lift: -50,
        bobAmplitude: inf,
      ),
    ];
    for (final MoodPose p in poses) {
      final _Img img = await _render(
        tester,
        _forSet(CoffinColorTokens.night, pose: p, bob: nan, headroom: 20),
        64,
        104,
        margin: 20,
      );
      expect(img.bytes.length, greaterThan(0));
    }
  });

  testWidgets('rendered body color of each mood keeps 3.0:1 in both themes', (
    tester,
  ) async {
    const double size = 96;
    final int reserve = MoodTraits.reserveFor(size);
    for (final CoffinColorTokens set in CoffinColorTokens.variants) {
      final int background = set.background.toARGB32();
      for (final GhostMood m in GhostMood.values) {
        final _Img img = await _render(
          tester,
          _forSet(
            set,
            pose: MoodPose.rest(m),
            headroom: reserve.toDouble(),
            glow: false,
          ),
          size,
          size + 2 * reserve,
          background: set.background,
        );
        const double w = 0.8 * size;
        final int px = (size / 2 - 0.3 * w).round();
        final int py = (reserve + 0.6 * w).round();
        final int body = img.argb(px, py);
        expect(
          WcagContrast.ratio(body, background),
          greaterThanOrEqualTo(3.0),
          reason: 'body vs background: $m ${set.name}',
        );
        expect(
          WcagContrast.ratio(background, body),
          greaterThanOrEqualTo(3.0),
          reason: 'eye vs body: $m ${set.name}',
        );
      }
    }
  });
}
