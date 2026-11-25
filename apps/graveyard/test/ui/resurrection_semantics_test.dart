import 'dart:ui' as ui;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/resurrection/clod_path_generator.dart';
import 'package:graveyard/src/domain/resurrection/hand_geometry.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/clods_painter.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/hand_painter.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/rest_dialog.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';
import '../support/fake_graveyard_clipboard.dart';

const String _name = 'Old Idea';
final CalendarDate _died = CalendarDate(2023, 1, 3);
final CalendarDate _risen = CalendarDate(2026, 5, 1);
final CalendarDate _today = CalendarDate(2026, 5, 10);

final Grave _manual = Grave.manual(id: 'a', name: _name, dateOfDeath: _died);
final Grave _livingManual = Grave.manual(
  id: 'a',
  name: _name,
  dateOfDeath: _died,
  risenOn: _risen,
);
final Grave _livingGithub = Grave.github(
  id: 'g',
  name: 'Alpha',
  dateOfDeath: _died,
  risenOn: _risen,
  repo: const RepoInfo(
    fullName: 'ann/alpha',
    htmlUrl: 'https://github.com/ann/alpha',
  ),
);

/// The two themes of the app with the tokens they are built from.
final Map<String, (ThemeData, CoffinColorTokens)> _themes =
    <String, (ThemeData, CoffinColorTokens)>{
      'dark': (CoffinTheme.dark(), CoffinColorTokens.night),
      'daylight': (CoffinTheme.light(), CoffinColorTokens.daylight),
    };

int _argb(Color c) => c.toARGB32();

double _ratio(Color a, Color b) => WcagContrast.ratio(_argb(a), _argb(b));

/// The color a [Text] really paints with, buttons included.
Color _textColor(Element e) {
  final Text t = e.widget as Text;
  final Color? c = DefaultTextStyle.of(e).style.merge(t.style).color;
  expect(c, isNotNull, reason: 'text "${t.data}" has no color');
  return c!;
}

Widget _host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _openRestDialog(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showRestDialog(context, _name),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showSeanceSheet(
              context,
              grave: _manual,
              today: _today,
              seanceAi: FakeCoffinAI.replying('Boo.'),
              onRaise: (Grave _) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// A screen with one dead grave called "Moon", for the play tests.
Future<void> _raiseOnScreen(
  WidgetTester tester, {
  required bool reduced,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Grave g = Grave.manual(id: 'm', name: 'Moon', dateOfDeath: _died);
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{g.id: ControllerHarness.envelopeOf(g)},
  );
  addTearDown(h.dispose);
  await h.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: GraveyardScreen(
        controller: h.controller,
        seanceAi: FakeCoffinAI.replying('Boo.'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.tap(find.byType(SeanceControl));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.tap(find.text(GraveyardCopy.raiseControlText));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
}

List<SemanticsNode> _allNodes(WidgetTester tester) {
  final List<SemanticsNode> out = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    out.add(n);
    n.visitChildren((SemanticsNode c) {
      walk(c);
      return true;
    });
  }

  SemanticsNode root = tester.getSemantics(find.byType(GraveyardScreen));
  while (root.parent != null) {
    root = root.parent!;
  }
  walk(root);
  return out;
}

/// A canvas that keeps the [Paint] of every path and circle it is given.
class _PaintCapture implements ui.Canvas {
  final List<Paint> paints = <Paint>[];

  /// The colors of the paints that are fully opaque (the glows are not).
  Set<Color> get opaqueColors => <Color>{
    for (final Paint p in paints)
      if (p.color.a == 1) p.color,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final String name = invocation.memberName.toString();
    if (name.contains('drawPath')) {
      paints.add(invocation.positionalArguments[1] as Paint);
    } else if (name.contains('drawCircle')) {
      paints.add(invocation.positionalArguments[2] as Paint);
    }
    return null;
  }
}

void main() {
  group('exact labels', () {
    testWidgets('Raise <name> from the dead on the sheet control', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSheet(tester, CoffinTheme.dark());
      expect(
        GraveyardCopy.raiseControlLabel(_name),
        'Raise Old Idea from the dead',
      );
      expect(
        find.bySemanticsLabel('Raise Old Idea from the dead'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Raise Old Idea from the dead'),
        ),
        matchesSemantics(
          label: 'Raise Old Idea from the dead',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('Lay <name> back to rest and the repository link label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          CoffinTheme.dark(),
          LivingRow(
            entries: <Grave>[_livingGithub],
            onLayToRest: (_) {},
            clipboard: RecordingGraveyardClipboard(),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Lay Alpha back to rest'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Copy the repository link of Alpha'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the dialog route is named "Lay <name> back to rest?"', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openRestDialog(tester, CoffinTheme.dark());
      final Element dialog = tester.element(find.byType(RestDialog));
      expect(
        ModalRoute.of(dialog)?.settings.name,
        'Lay Old Idea back to rest?',
      );
      final Finder named = find.byWidgetPredicate(
        (Widget w) =>
            w is Semantics &&
            w.properties.namesRoute == true &&
            w.properties.scopesRoute == true &&
            w.properties.label == 'Lay Old Idea back to rest?',
      );
      expect(named, findsOneWidget);
      handle.dispose();
    });

    testWidgets('one polite live region says "<name> has risen."', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _raiseOnScreen(tester, reduced: true);
      final Finder announced = find.bySemanticsLabel('Moon has risen.');
      expect(announced, findsOneWidget);
      expect(
        tester
            .getSemantics(announced)
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 4));
      handle.dispose();
    });
  });

  group('the Living_Row semantics', () {
    testWidgets('heading is a header; one text node per entry; own nodes for '
        'the controls', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          CoffinTheme.dark(),
          LivingRow(
            entries: <Grave>[_livingGithub, _livingManual],
            onLayToRest: (_) {},
            clipboard: RecordingGraveyardClipboard(),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text(GraveyardCopy.livingRowHeading)),
        matchesSemantics(label: GraveyardCopy.livingRowHeading, isHeader: true),
      );
      final String githubLine = GraveyardCopy.risenOnLine(_risen);
      expect(find.bySemanticsLabel('Alpha. $githubLine'), findsOneWidget);
      expect(find.bySemanticsLabel('$_name. $githubLine'), findsOneWidget);
      // The visible texts are not exposed a second time.
      expect(find.bySemanticsLabel('Alpha'), findsNothing);
      expect(find.bySemanticsLabel(githubLine), findsNothing);
      // Controls are their own button nodes.
      for (final String label in <String>[
        'Lay Alpha back to rest',
        'Lay $_name back to rest',
        'Copy the repository link of Alpha',
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(label: label, isButton: true, hasTapAction: true),
          reason: label,
        );
      }
      handle.dispose();
    });
  });

  group('the Resurrection_Play exposes nothing', () {
    {
      testWidgets('no node for the hand, clods, glows or ghost; the loader '
          'label is not read', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _raiseOnScreen(tester, reduced: false);
        // The play is running now and the ghost is on the stone.
        final Finder play = find.byType(ResurrectionPlay);
        expect(play, findsOneWidget);
        expect(
          find.descendant(of: play, matching: find.byType(GhostLoader)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: play, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
        final List<SemanticsNode> nodes = _allNodes(tester);
        for (final SemanticsNode n in nodes) {
          expect(n.label, isNot(contains('Loading')));
          expect(n.hint, isNot(contains('Loading')));
        }
        expect(find.bySemanticsLabel('Loading'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        handle.dispose();
      });
    }
  });

  group('tap targets and labels', () {
    testWidgets('Raise it is at least 48x48 and labelled', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openSheet(tester, CoffinTheme.dark());
      final Size s = tester.getSize(
        find.byKey(const ValueKey<String>('seance-raise')),
      );
      expect(s.width, greaterThanOrEqualTo(48));
      expect(s.height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel(GraveyardCopy.raiseControlLabel(_name)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('Lay it back to rest and the repository link', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          CoffinTheme.dark(),
          LivingRow(
            entries: <Grave>[_livingGithub],
            onLayToRest: (_) {},
            clipboard: RecordingGraveyardClipboard(),
          ),
        ),
      );
      for (final Finder button in <Finder>[
        find.byKey(const ValueKey<String>('lay-to-rest-g')),
        find.descendant(
          of: find.byKey(const ValueKey<String>('repository-link-g')),
          matching: find.byType(TextButton),
        ),
      ]) {
        final Size s = tester.getSize(button);
        expect(s.width, greaterThanOrEqualTo(48));
        expect(s.height, greaterThanOrEqualTo(48));
      }
      expect(find.bySemanticsLabel('Lay Alpha back to rest'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Copy the repository link of Alpha'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('both Rest_Dialog buttons', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _openRestDialog(tester, CoffinTheme.dark());
      for (final String key in <String>['rest-confirm', 'rest-cancel']) {
        final Size s = tester.getSize(find.byKey(ValueKey<String>(key)));
        expect(s.width, greaterThanOrEqualTo(48), reason: key);
        expect(s.height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(
        find.bySemanticsLabel(GraveyardCopy.restConfirmText),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(GraveyardCopy.restCancelText),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('contrast', () {
    for (final MapEntry<String, (ThemeData, CoffinColorTokens)> entry
        in _themes.entries) {
      final ThemeData theme = entry.value.$1;
      final CoffinColorTokens tokens = entry.value.$2;

      testWidgets('Living_Row and Living_Entry in the ${entry.key} theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            theme,
            LivingRow(
              entries: <Grave>[_livingGithub, _livingManual],
              onLayToRest: (_) {},
              clipboard: RecordingGraveyardClipboard(),
            ),
          ),
        );
        // Show the "Link copied" line too.
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey<String>('repository-link-g')),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pump();
        int texts = 0;
        for (final Element e
            in find
                .descendant(
                  of: find.byType(LivingRow),
                  matching: find.byType(Text),
                )
                .evaluate()) {
          final String data = (e.widget as Text).data ?? '';
          final Color color = _textColor(e);
          // The heading sits on the sky, which runs from background to
          // surface; every entry text sits on the entry's surface.
          final List<Color> behind = data == GraveyardCopy.livingRowHeading
              ? <Color>[tokens.background, tokens.surface]
              : <Color>[tokens.surface];
          for (final Color b in behind) {
            expect(
              _ratio(color, b),
              greaterThanOrEqualTo(WcagContrast.aaNormalText),
              reason: '"$data" in ${entry.key}',
            );
          }
          texts++;
        }
        // Heading, 2 names, 2 risen lines, link, 2 rest controls, status.
        expect(texts, 9);
        for (final Element e
            in find
                .descendant(
                  of: find.byType(LivingRow),
                  matching: find.byType(Icon),
                )
                .evaluate()) {
          final Icon i = e.widget as Icon;
          final Color? c = i.color ?? IconTheme.of(e).color;
          expect(c, isNotNull);
          expect(_ratio(c!, tokens.surface), greaterThanOrEqualTo(3.0));
        }
      });

      testWidgets('Rest_Dialog in the ${entry.key} theme', (tester) async {
        await _openRestDialog(tester, theme);
        final Finder dialog = find.byType(AlertDialog);
        expect(
          tester.widget<AlertDialog>(dialog).backgroundColor,
          tokens.raised,
        );
        int texts = 0;
        for (final Element e
            in find
                .descendant(of: dialog, matching: find.byType(Text))
                .evaluate()) {
          expect(
            _ratio(_textColor(e), tokens.raised),
            greaterThanOrEqualTo(WcagContrast.aaNormalText),
            reason: '"${(e.widget as Text).data}" in ${entry.key}',
          );
          texts++;
        }
        // Title, body, cancel and confirm.
        expect(texts, 4);
        for (final Element e
            in find
                .descendant(of: dialog, matching: find.byType(Icon))
                .evaluate()) {
          final Icon i = e.widget as Icon;
          final Color? c = i.color ?? IconTheme.of(e).color;
          expect(_ratio(c!, tokens.raised), greaterThanOrEqualTo(3.0));
        }
      });

      test('Hand, Clods and ghost against the stone and the ground in the '
          '${entry.key} theme', () {
        final _PaintCapture hand = _PaintCapture();
        const Size size = Size(200, 300);
        HandPainter(
          shape: HandGeometry.at(
            width: size.width,
            height: size.height,
            elapsedMs: PlayTiming.handBurstEndMs,
          ),
          tokens: tokens,
        ).paint(hand, size);
        final _PaintCapture clods = _PaintCapture();
        for (int ms = 0; ms <= PlayTiming.handSinkEndMs; ms += 20) {
          ClodsPainter(
            clods: ClodPathGenerator.generate('a'),
            elapsedMs: ms,
            tokens: tokens,
          ).paint(clods, size);
        }
        expect(hand.opaqueColors, isNotEmpty);
        expect(clods.opaqueColors, isNotEmpty);
        // The stone is the tombstone surface, the ground is the background,
        // and the ghost body is the primary token (GhostLoader).
        final Map<String, Set<Color>> drawn = <String, Set<Color>>{
          'hand': hand.opaqueColors,
          'clods': clods.opaqueColors,
          'ghost': <Color>{tokens.primary},
        };
        for (final MapEntry<String, Set<Color>> d in drawn.entries) {
          for (final Color c in d.value) {
            expect(
              _ratio(c, tokens.surface),
              greaterThanOrEqualTo(3.0),
              reason: '${d.key} on the stone in ${entry.key}',
            );
            expect(
              _ratio(c, tokens.background),
              greaterThanOrEqualTo(3.0),
              reason: '${d.key} on the ground in ${entry.key}',
            );
          }
        }
      });
    }
  });
}
