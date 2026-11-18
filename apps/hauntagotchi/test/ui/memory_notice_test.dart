import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/memory_notice.dart';

void main() {
  testWidgets('shows the memory notice with a semantic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: const Scaffold(body: MemoryNotice()),
      ),
    );
    expect(find.text(HauntCopy.memoryNotice), findsOneWidget);
    expect(find.bySemanticsLabel(HauntCopy.memoryNotice), findsOneWidget);
    handle.dispose();
  });
}
