import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/save_error_banner.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback onRetry) {
    return tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Scaffold(body: SaveErrorBanner(onRetry: onRetry)),
      ),
    );
  }

  testWidgets('shows the message and Retry calls onRetry', (tester) async {
    var retries = 0;
    await pump(tester, () => retries++);
    expect(find.text(HauntCopy.saveError), findsOneWidget);
    await tester.tap(find.text(HauntCopy.retry));
    expect(retries, 1);
  });

  testWidgets('Retry is labelled and at least 48x48', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, () {});
    expect(find.bySemanticsLabel(HauntCopy.retry), findsOneWidget);
    final size = tester.getSize(
      find.ancestor(
        of: find.text(HauntCopy.retry),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
