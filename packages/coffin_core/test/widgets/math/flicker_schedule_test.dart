import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlickerSchedule', () {
    test('seed 0 gives the pinned levels', () {
      const List<int> percents = <int>[
        93, 76, 91, 83, 93, 80, 78, 81, //
        80, 87, 100, 80, 96, 88, 79, 89,
      ];
      final List<double> levels = FlickerSchedule(0).levels;
      expect(levels.take(4).toList(), <double>[0.93, 0.76, 0.91, 0.83]);
      expect(levels, <double>[for (final int p in percents) p / 100]);
    });

    test('levels[i] equals opacityAt(i * 400)', () {
      for (final int seed in <int>[0, 1, 42, 4294967295]) {
        final FlickerSchedule schedule = FlickerSchedule(seed);
        for (int i = 0; i < FlickerSchedule.levelCount; i++) {
          expect(schedule.levels[i], schedule.opacityAt(i * 400));
        }
      }
    });

    test('seeds 0 to 15 give at least two different schedules', () {
      final Set<String> seen = <String>{
        for (int seed = 0; seed < 16; seed++)
          FlickerSchedule(seed).levels.join(','),
      };
      expect(seen.length, greaterThanOrEqualTo(2));
    });

    test('levels cannot be modified', () {
      final List<double> levels = FlickerSchedule(7).levels;
      expect(() => levels[0] = 0.5, throwsUnsupportedError);
      expect(() => levels.add(0.5), throwsUnsupportedError);
    });

    test('negative time gives an in-range value', () {
      final FlickerSchedule schedule = FlickerSchedule(3);
      for (final int t in <int>[-1, -399, -6400, -123456789]) {
        final double o = schedule.opacityAt(t);
        expect(o, inInclusiveRange(0.75, 1.0));
      }
    });

    test('seed is masked to 32 bits', () {
      expect(FlickerSchedule(-1).seed, 4294967295);
      expect(FlickerSchedule(4294967296).levels, FlickerSchedule(0).levels);
    });

    test('staticOpacity is 1.0', () {
      expect(FlickerSchedule.staticOpacity, 1.0);
    });
  });
}
