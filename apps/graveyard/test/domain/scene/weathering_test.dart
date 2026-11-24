import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/stable_hash.dart';
import 'package:graveyard/src/domain/scene/weathering.dart';

void main() {
  group('Weathering', () {
    test('day count 0 gives level 0, tilt 0 and fade 0', () {
      final r = Weathering.of(dayCount: 0, graveId: 'a');
      expect(r.level, 0);
      expect(r.tiltRadians, 0);
      expect(r.fade, 0);
    });

    test('negative day count behaves like 0', () {
      final neg = Weathering.of(dayCount: -40, graveId: 'a');
      final zero = Weathering.of(dayCount: 0, graveId: 'a');
      expect(neg.level, zero.level);
      expect(neg.tiltRadians, zero.tiltRadians);
      expect(neg.fade, zero.fade);
    });

    test('3650 days and above give level 1', () {
      expect(Weathering.of(dayCount: 3650, graveId: 'a').level, 1);
      expect(Weathering.of(dayCount: 9999, graveId: 'a').level, 1);
    });

    test('tilt sign is fixed for a fixed id', () {
      final first = Weathering.of(dayCount: 1000, graveId: 'grave-1');
      final second = Weathering.of(dayCount: 2000, graveId: 'grave-1');
      expect(first.tiltRadians.sign, second.tiltRadians.sign);
    });

    test('tilt sign differs between at least one pair of ids', () {
      final signs = {
        for (final id in List.generate(50, (i) => 'id-$i'))
          Weathering.of(dayCount: 3650, graveId: id).tiltRadians.sign,
      };
      expect(signs, containsAll(<double>[1, -1]));
    });

    test('tilt sign equals the parity of StableHash.of(id)', () {
      for (final id in List.generate(30, (i) => 'project-$i')) {
        final expected = StableHash.of(id).isEven ? 1.0 : -1.0;
        final tilt = Weathering.of(dayCount: 3650, graveId: id).tiltRadians;
        expect(tilt.sign, expected, reason: id);
      }
    });
  });
}
