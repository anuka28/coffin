import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/empty_graveyard_panel.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/load_error_view.dart';
import 'package:graveyard/src/ui/memory_notice.dart';
import 'package:graveyard/src/ui/save_error_banner.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void _expectTapTarget(WidgetTester tester, String key) {
  final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}

void main() {
  testWidgets('empty panel names both ways and each button calls back', (
    tester,
  ) async {
    int bury = 0;
    int import = 0;
    await _pump(
      tester,
      EmptyGraveyardPanel(onBuryByHand: () => bury++, onImport: () => import++),
    );
    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
    expect(find.text(GraveyardCopy.emptyBody), findsOneWidget);
    _expectTapTarget(tester, 'empty-bury');
    _expectTapTarget(tester, 'empty-import');
    await tester.tap(find.byKey(const ValueKey<String>('empty-bury')));
    await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
    expect(bury, 1);
    expect(import, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('memory notice shows the gentle text', (tester) async {
    await _pump(tester, const MemoryNotice());
    expect(find.text(GraveyardCopy.memoryNotice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save error banner retries', (tester) async {
    int retries = 0;
    await _pump(tester, SaveErrorBanner(onRetry: () => retries++));
    expect(find.text(GraveyardCopy.saveError), findsOneWidget);
    _expectTapTarget(tester, 'save-retry');
    await tester.tap(find.byKey(const ValueKey<String>('save-retry')));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load error view retries', (tester) async {
    int retries = 0;
    await _pump(tester, LoadErrorView(onRetry: () => retries++));
    expect(find.text(GraveyardCopy.loadError), findsOneWidget);
    _expectTapTarget(tester, 'load-retry');
    await tester.tap(find.byKey(const ValueKey<String>('load-retry')));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
