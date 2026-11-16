import 'dart:ui' as ui;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] under the dark theme, using only barrel names.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Replaces the tree and lets every loop and tween stop.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('widgets through the barrel', () {
    testWidgets('GhostLoader builds', (tester) async {
      await _pump(tester, const GhostLoader(caption: 'Summoning'));
      expect(find.byType(GhostLoader), findsOneWidget);
      expect(find.text('Summoning'), findsWidgets);
      await _teardown(tester);
    });

    testWidgets('TombstoneCard builds', (tester) async {
      await _pump(tester, const TombstoneCard(title: 'Old project'));
      expect(find.byType(TombstoneCard), findsOneWidget);
      expect(find.text('Old project'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('FlickerText builds', (tester) async {
      await _pump(tester, const FlickerText('Boo'));
      expect(find.byType(FlickerText), findsOneWidget);
      expect(find.text('Boo'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('FogBackground builds', (tester) async {
      await _pump(tester, const FogBackground(child: Text('Mist')));
      expect(find.byType(FogBackground), findsOneWidget);
      expect(find.text('Mist'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('CryptGallery builds', (tester) async {
      await _pump(tester, const CryptGallery());
      expect(find.byType(CryptGallery), findsOneWidget);
      await _teardown(tester);
    });

    test('GhostPainter draws on a canvas', () {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const GhostPainter(
        bodyColor: Color(0xFFFFFFFF),
        eyeColor: Color(0xFF000000),
      ).paint(canvas, const Size(64, 64));
      final ui.Picture picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });
  });
}
