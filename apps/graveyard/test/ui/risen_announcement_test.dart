import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/risen_announcement.dart';

Widget _host(int announcement, String? name) => Directionality(
  textDirection: TextDirection.ltr,
  child: RisenAnnouncement(announcement: announcement, name: name),
);

void main() {
  testWidgets('exposes nothing before the first Raise', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(0, null));
    expect(find.bySemanticsLabel(RegExp('has risen')), findsNothing);
    handle.dispose();
  });

  testWidgets('exposes one polite live region per Raise', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(1, 'Moon'));
    final SemanticsNode node = tester.getSemantics(
      find.bySemanticsLabel(GraveyardCopy.risenAnnouncement('Moon')),
    );
    expect(node.label, GraveyardCopy.risenAnnouncement('Moon'));
    // ignore: deprecated_member_use
    expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    // A rebuild with the same counter keeps the same node.
    await tester.pumpWidget(_host(1, 'Moon'));
    expect(
      find.bySemanticsLabel(GraveyardCopy.risenAnnouncement('Moon')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('has no visual output', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(child: RisenAnnouncement(announcement: 2, name: 'Moon')),
      ),
    );
    final Finder box = find.descendant(
      of: find.byType(RisenAnnouncement),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(box), Size.zero);
  });
}
