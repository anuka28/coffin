import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/ui/graveyard_clipboard.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/repository_link.dart';

import '../support/fake_graveyard_clipboard.dart';

class _FakeClipboard implements GraveyardClipboard {
  _FakeClipboard({this.failure});

  final Object? failure;
  final List<String> copied = <String>[];

  @override
  Future<void> copy(String text) async {
    final Object? error = failure;
    if (error != null) {
      throw error;
    }
    copied.add(text);
  }
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

RepositoryLink _link(GraveyardClipboard clipboard) => RepositoryLink(
  name: 'Alpha',
  fullName: 'ann/alpha',
  address: 'https://github.com/ann/alpha',
  clipboard: clipboard,
);

void main() {
  testWidgets('shows the full name, 48x48, with a semantic label', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_link(_FakeClipboard())));
    expect(find.text('ann/alpha'), findsOneWidget);
    final Size size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(GraveyardCopy.repositoryLinkLabel('Alpha')),
      findsOneWidget,
    );
  });

  testWidgets('copies the address and confirms', (tester) async {
    final _FakeClipboard clipboard = _FakeClipboard();
    await tester.pumpWidget(_host(_link(clipboard)));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(clipboard.copied, <String>['https://github.com/ann/alpha']);
    expect(find.text(GraveyardCopy.linkCopied), findsOneWidget);
    expect(find.text('ann/alpha'), findsOneWidget);
  });

  testWidgets('any thrown object shows the failure line and no exception', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_link(_FakeClipboard(failure: 'nope'))));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text(GraveyardCopy.linkCopyFailed), findsOneWidget);
    expect(find.text(GraveyardCopy.linkCopied), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activates from the keyboard', (tester) async {
    final _FakeClipboard clipboard = _FakeClipboard();
    await tester.pumpWidget(_host(_link(clipboard)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(clipboard.copied, hasLength(1));
  });

  testWidgets('living row: github grave with address shows one link', (
    tester,
  ) async {
    final _FakeClipboard clipboard = _FakeClipboard();
    final Grave github = Grave.github(
      id: 'g',
      name: 'Alpha',
      dateOfDeath: CalendarDate(2024, 1, 1),
      repo: const RepoInfo(
        fullName: 'ann/alpha',
        htmlUrl: 'https://github.com/ann/alpha',
      ),
      risenOn: CalendarDate(2025, 5, 2),
    );
    final Grave manual = Grave.manual(
      id: 'm',
      name: 'Beta',
      dateOfDeath: CalendarDate(2024, 1, 1),
      risenOn: CalendarDate(2025, 5, 1),
    );
    await tester.pumpWidget(
      _host(
        LivingRow(
          entries: <Grave>[github, manual],
          onLayToRest: (_) {},
          clipboard: clipboard,
        ),
      ),
    );
    expect(find.byType(RepositoryLink), findsOneWidget);
    expect(find.text('ann/alpha'), findsOneWidget);
    await tester.tap(find.text('ann/alpha'));
    await tester.pump();
    expect(clipboard.copied, <String>['https://github.com/ann/alpha']);
  });

  testWidgets('living row: github grave without address shows no link', (
    tester,
  ) async {
    final Grave github = Grave.github(
      id: 'g',
      name: 'Alpha',
      dateOfDeath: CalendarDate(2024, 1, 1),
      repo: const RepoInfo(fullName: 'ann/alpha'),
      risenOn: CalendarDate(2025, 5, 2),
    );
    await tester.pumpWidget(
      _host(LivingRow(entries: <Grave>[github], onLayToRest: (_) {})),
    );
    expect(find.byType(RepositoryLink), findsNothing);
  });

  group('Repository_Link with shared clipboard fakes', () {
    final Grave github = Grave.github(
      id: 'g',
      name: 'Alpha',
      dateOfDeath: CalendarDate(2024, 1, 1),
      repo: const RepoInfo(
        fullName: 'ann/alpha',
        htmlUrl: 'https://github.com/ann/alpha',
      ),
      risenOn: CalendarDate(2025, 5, 2),
    );
    final Grave manual = Grave.manual(
      id: 'm',
      name: 'Beta',
      dateOfDeath: CalendarDate(2024, 1, 1),
      risenOn: CalendarDate(2025, 5, 1),
    );

    Widget row(GraveyardClipboard clipboard, List<Grave> entries) => _host(
      LivingRow(entries: entries, onLayToRest: (_) {}, clipboard: clipboard),
    );

    testWidgets('recording clipboard holds the address and shows the note', (
      tester,
    ) async {
      final RecordingGraveyardClipboard clipboard =
          RecordingGraveyardClipboard();
      await tester.pumpWidget(row(clipboard, <Grave>[github]));
      expect(find.text('ann/alpha'), findsOneWidget);
      await tester.tap(find.byType(RepositoryLink));
      await tester.pump();
      expect(clipboard.copied, <String>['https://github.com/ann/alpha']);
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('throwing clipboard shows the failure and leaves the entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        row(const ThrowingGraveyardClipboard(), <Grave>[github]),
      );
      final String risen = GraveyardCopy.risenOnLine(github.risenOn!);
      await tester.tap(find.byType(RepositoryLink));
      await tester.pump();
      expect(
        find.text('That link would not copy. Try once more.'),
        findsOneWidget,
      );
      expect(find.text('Link copied'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text(risen), findsOneWidget);
      expect(find.text('ann/alpha'), findsOneWidget);
      expect(find.text(GraveyardCopy.layToRestText), findsOneWidget);
      expect(find.byType(RepositoryLink), findsOneWidget);
    });

    testWidgets('semantic label names the grave', (tester) async {
      await tester.pumpWidget(
        row(RecordingGraveyardClipboard(), <Grave>[github]),
      );
      expect(
        find.bySemanticsLabel('Copy the repository link of Alpha'),
        findsOneWidget,
      );
    });

    testWidgets('tap target is at least 48 by 48', (tester) async {
      await tester.pumpWidget(
        row(RecordingGraveyardClipboard(), <Grave>[github]),
      );
      final Size size = tester.getSize(find.byType(RepositoryLink));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      testWidgets(
        '${key.keyLabel.isEmpty ? 'Space' : key.keyLabel} activates',
        (tester) async {
          final RecordingGraveyardClipboard clipboard =
              RecordingGraveyardClipboard();
          await tester.pumpWidget(row(clipboard, <Grave>[github]));
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          await tester.sendKeyEvent(key);
          await tester.pump();
          expect(clipboard.copied, <String>['https://github.com/ann/alpha']);
          expect(find.text('Link copied'), findsOneWidget);
        },
      );
    }

    testWidgets('a manual grave shows no link', (tester) async {
      await tester.pumpWidget(
        row(RecordingGraveyardClipboard(), <Grave>[manual]),
      );
      expect(find.byType(RepositoryLink), findsNothing);
    });
  });
}
