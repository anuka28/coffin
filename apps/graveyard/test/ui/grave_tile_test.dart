import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/ui/grave_tile.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

final Grave _manual = Grave.manual(
  id: 'a',
  name: 'Old Idea',
  dateOfDeath: CalendarDate(2024, 1, 3),
);

final Grave _github = Grave.github(
  id: 'b',
  name: 'flutter',
  dateOfDeath: CalendarDate(2023, 1, 3),
  repo: const RepoInfo(
    fullName: 'flutter/flutter',
    stars: 181478,
    archived: true,
    description: 'Build apps for any screen',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Grave grave, {
  VoidCallback? onDelete,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: CoffinTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: GraveTile(
            grave: grave,
            today: _today,
            onDelete: onDelete ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('manual grave shows name, date line and Buried by hand', (
    tester,
  ) async {
    await _pump(tester, _manual);
    expect(find.text('Old Idea'), findsOneWidget);
    expect(find.text('Died 3 Jan 2024'), findsOneWidget);
    expect(find.text('Dead for 1 week'), findsOneWidget);
    expect(find.text('Buried by hand.'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('GitHub grave shows facts, star icon and description', (
    tester,
  ) async {
    await _pump(tester, _github);
    expect(find.text('flutter/flutter'), findsOneWidget);
    expect(find.text('181478, Archived'), findsOneWidget);
    expect(find.textContaining('★'), findsNothing);
    expect(find.text('Build apps for any screen'), findsOneWidget);
    final Text description = tester.widget(
      find.text('Build apps for any screen'),
    );
    expect(description.maxLines, 3);
    expect(description.overflow, TextOverflow.ellipsis);
    expect(find.text('Buried by hand.'), findsNothing);
  });

  testWidgets('star icon sits inside ExcludeSemantics', (tester) async {
    await _pump(tester, _github);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.star),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
  });

  testWidgets('one container label covers the grave', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, _github);
    expect(
      find.bySemanticsLabel(
        'flutter. Dead for 1 year. From GitHub, flutter/flutter, '
        '181478 stars, archived. Description: Build apps for any screen',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('181478, Archived'), findsNothing);
    await _pump(tester, _manual);
    expect(
      find.bySemanticsLabel('Old Idea. Dead for 1 week. Buried by hand.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('epitaph shows at normal scale and hides at large scale', (
    tester,
  ) async {
    await _pump(tester, _manual);
    expect(find.text('Dead for 1 week. Rest easy.'), findsOneWidget);
    await _pump(tester, _manual, textScale: 1.5);
    expect(find.text('Dead for 1 week. Rest easy.'), findsNothing);
  });

  testWidgets('delete button is labelled, 48 by 48 and calls back', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int calls = 0;
    await _pump(tester, _manual, onDelete: () => calls++);
    expect(find.bySemanticsLabel('Delete Old Idea'), findsOneWidget);
    final Size size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(TextButton));
    expect(calls, 1);
    handle.dispose();
  });
}
