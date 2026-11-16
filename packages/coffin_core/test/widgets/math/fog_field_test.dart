import 'package:coffin_core/src/widgets/math/fog_field.dart';
import 'package:coffin_core/src/widgets/math/fog_particle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FogField count', () {
    test('clamps the count into 0..24', () {
      expect(FogField(seed: 1, count: -1).particlesAt(0), isEmpty);
      expect(FogField(seed: 1, count: 0).particlesAt(0), isEmpty);
      expect(FogField(seed: 1, count: 24).particlesAt(0), hasLength(24));
      expect(FogField(seed: 1, count: 25).particlesAt(0), hasLength(24));
      expect(FogField(seed: 1, count: 25).count, 24);
      expect(FogField(seed: 1).particlesAt(0), hasLength(10));
    });
  });

  group('FogField particles', () {
    test('radius and alpha stay in range at several times', () {
      for (var seed = 0; seed < 16; seed++) {
        final field = FogField(seed: seed, count: 24);
        for (final t in [0, 1234, 45000, 99999, -50000]) {
          for (final p in field.particlesAt(t)) {
            expect(p.radius, inInclusiveRange(0.12, 0.30));
            expect(p.alpha, inInclusiveRange(0.03, 0.05));
            expect(p.x, inInclusiveRange(0, 1));
            expect(p.y, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('seeds 0 to 15 give at least two different fields', () {
      final fields = {
        for (var s = 0; s < 16; s++)
          FogField(seed: s).staticParticles.toString(),
      };
      expect(fields.length, greaterThan(1));
    });

    test('staticParticles equals particlesAt(0)', () {
      final field = FogField(seed: 7);
      expect(field.staticParticles, field.particlesAt(0));
    });

    test('the first particle of seed 0 is the same on every call', () {
      final field = FogField(seed: 0);
      final first = field.particlesAt(0).first;
      expect(field.particlesAt(0).first, first);
      expect(FogField(seed: 0).particlesAt(0).first, first);
    });
  });

  group('FogParticle', () {
    test('has value equality and a readable toString', () {
      const a = FogParticle(x: 0.1, y: 0.2, radius: 0.3, alpha: 0.04);
      const b = FogParticle(x: 0.1, y: 0.2, radius: 0.3, alpha: 0.04);
      const c = FogParticle(x: 0.1, y: 0.2, radius: 0.3, alpha: 0.05);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(
        a.toString(),
        'FogParticle(x: 0.1, y: 0.2, radius: 0.3, alpha: 0.04)',
      );
    });
  });

  group('FogField.toBounds', () {
    const p = FogParticle(x: 0.5, y: 0.25, radius: 0.2, alpha: 0.04);

    test('maps into a normal box', () {
      final d = FogField.toBounds(p, 200, 100);
      expect(d.x, 100);
      expect(d.y, 25);
      expect(d.radius, 0.2 * 100);
    });

    test('a zero dimension gives an all-zero disc', () {
      final zero = FogField.toBounds(p, 0, 100);
      expect((zero.x, zero.y, zero.radius), (0.0, 25.0, 0.0));
      final zeroH = FogField.toBounds(p, 100, 0);
      expect((zeroH.x, zeroH.y, zeroH.radius), (50.0, 0.0, 0.0));
    });

    test('a half-pixel box stays valid', () {
      final d = FogField.toBounds(p, 0.5, 0.5);
      expect(d.x, inInclusiveRange(0, 0.5));
      expect(d.radius, inInclusiveRange(0, 0.5));
    });

    test('negative, NaN and infinite dimensions count as 0', () {
      for (final bad in [-5.0, double.nan, double.infinity]) {
        final d = FogField.toBounds(p, bad, 100);
        expect(d.x, 0);
        expect(d.radius, 0);
        final e = FogField.toBounds(p, 100, bad);
        expect(e.y, 0);
        expect(e.radius, 0);
      }
    });

    test('out-of-range unit values are clamped', () {
      const wild = FogParticle(x: 2, y: -1, radius: double.nan, alpha: 0.04);
      final d = FogField.toBounds(wild, 100, 50);
      expect((d.x, d.y, d.radius), (100.0, 0.0, 0.0));
    });
  });
}
