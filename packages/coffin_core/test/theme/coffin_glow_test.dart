import 'package:coffin_core/src/theme/coffin_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const color = Color(0xFF9B6BFF);

  group('CoffinGlow.decoration', () {
    test('applies fill override', () {
      final d = CoffinGlow.decoration(color: color, fill: Colors.black);
      expect(d.color, Colors.black);
      expect(CoffinGlow.decoration(color: color).color, isNull);
    });

    test('applies radius override', () {
      final r = BorderRadius.circular(4);
      final d = CoffinGlow.decoration(color: color, borderRadius: r);
      expect(d.borderRadius, r);
    });

    test('default radius is 16', () {
      final d = CoffinGlow.decoration(color: color);
      expect(d.borderRadius, BorderRadius.circular(16));
    });

    test('NaN intensity gives no shadows', () {
      final d = CoffinGlow.decoration(color: color, intensity: double.nan);
      expect(d.boxShadow, isEmpty);
    });

    test('zero intensity gives no shadows', () {
      final d = CoffinGlow.decoration(color: color, intensity: 0);
      expect(d.boxShadow, isEmpty);
    });

    test('intensity 1 gives two zero-offset shadows with blur 24 and 64', () {
      final d = CoffinGlow.decoration(color: color, intensity: 1);
      final shadows = d.boxShadow!;
      expect(shadows, hasLength(2));
      expect(shadows[0].blurRadius, closeTo(24, 1e-9));
      expect(shadows[1].blurRadius, closeTo(64, 1e-9));
      for (final s in shadows) {
        expect(s.offset, Offset.zero);
        expect(s.spreadRadius, 0);
      }
    });

    test('negative intensity clamps to none', () {
      final d = CoffinGlow.decoration(color: color, intensity: -3);
      expect(d.boxShadow, isEmpty);
    });

    test('intensity above 1 equals intensity 1', () {
      final a = CoffinGlow.decoration(color: color, intensity: 5);
      final b = CoffinGlow.decoration(color: color, intensity: 1);
      expect(a.boxShadow, b.boxShadow);
    });
  });

  group('semantics', () {
    Widget host(Decoration? decoration) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Container(width: 100, height: 100, decoration: decoration),
      ),
    );

    int countNodes(SemanticsNode? node) {
      if (node == null) return 0;
      var count = 1;
      node.visitChildren((child) {
        count += countNodes(child);
        return true;
      });
      return count;
    }

    testWidgets('glow decoration adds no semantics nodes', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(host(const BoxDecoration()));
      final plain = countNodes(
        tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode,
      );

      await tester.pumpWidget(
        host(
          CoffinGlow.decoration(color: color, intensity: 1, fill: Colors.black),
        ),
      );
      final glow = countNodes(
        tester.binding.rootPipelineOwner.semanticsOwner!.rootSemanticsNode,
      );

      expect(glow, plain);
      handle.dispose();
    });
  });
}
