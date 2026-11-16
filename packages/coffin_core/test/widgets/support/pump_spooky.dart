import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widths (logical pixels) every widget test should cover.
const List<double> testWidths = [320, 360, 1280];

/// Text scale factors every widget test should cover.
const List<double> testTextScales = [1.0, 1.5];

/// Pumps [child] once inside a themed [MaterialApp] with a fixed-size host.
///
/// The test view is resized to [width] x [height] logical pixels (device
/// pixel ratio 1) and reset when the test ends. [MediaQuery] reports the same
/// size, a linear [textScale] and `disableAnimations == reducedMotion`.
/// [brightness] picks `CoffinTheme.dark()` or `CoffinTheme.light()`.
Future<void> pumpSpooky(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 360,
  double height = 800,
  double textScale = 1.0,
  bool reducedMotion = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark
          ? CoffinTheme.dark()
          : CoffinTheme.light(),
      home: Builder(
        builder: (BuildContext context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: Material(child: child),
            ),
          );
        },
      ),
    ),
  );
}
