import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction_kind.dart';

void main() {
  group('GhostReactionKind', () {
    test('has fed and rising in order', () {
      expect(GhostReactionKind.values, [
        GhostReactionKind.fed,
        GhostReactionKind.rising,
      ]);
    });
  });

  group('GhostReaction', () {
    test('equal kind and key are equal with equal hash', () {
      const a = GhostReaction(GhostReactionKind.fed, 1);
      const b = GhostReaction(GhostReactionKind.fed, 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different kind or key are not equal', () {
      const a = GhostReaction(GhostReactionKind.fed, 1);
      expect(a == const GhostReaction(GhostReactionKind.rising, 1), isFalse);
      expect(a == const GhostReaction(GhostReactionKind.fed, 2), isFalse);
    });

    test('exposes kind and key', () {
      const r = GhostReaction(GhostReactionKind.rising, 7);
      expect(r.kind, GhostReactionKind.rising);
      expect(r.key, 7);
    });
  });
}
