import 'package:flutter_test/flutter_test.dart'
    show
        equals,
        expect,
        greaterThanOrEqualTo,
        group,
        inInclusiveRange,
        isTrue,
        lessThan,
        test;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/domain/voice_seed.dart';
import 'package:hauntagotchi/src/domain/voice_trigger.dart';

import 'support/haunt_generators.dart';

const int _numRuns = 300;
const int _maxSeed = 4294967290;
const int _base = 1000003;
const int _twoToThe53 = 9007199254740992;

final RunCounter _rangeRuns = RunCounter();
final RunCounter _productRuns = RunCounter();
final RunCounter _sensitivityRuns = RunCounter();
final RunCounter _stabilityRuns = RunCounter();
int _pairs = 0;
int _changed = 0;

Generator<int> get _anyDay => anyIntBetween(-100000, 100001);
Generator<int> get _anyState => anyIntBetween(0, GhostState.values.length);
Generator<int> get _anyTrigger => anyIntBetween(0, VoiceTrigger.values.length);
Generator<int> get _anyStreak => anyIntBetween(0, 1000001);
Generator<int> get _anyCompleted => anyIntBetween(0, 13);

typedef _Inputs = (int, int, int, int, int);
typedef _Pair = (_Inputs, int);

Generator<_Inputs> get _anyInputs =>
    any.combine5<int, int, int, int, int, _Inputs>(
      _anyDay,
      _anyState,
      _anyTrigger,
      _anyStreak,
      _anyCompleted,
      (int a, int b, int c, int d, int e) => (a, b, c, d, e),
    );

Generator<_Pair> get _anyPair => any.combine2<_Inputs, int, _Pair>(
  _anyInputs,
  anyIntBetween(0, 5000),
  (_Inputs i, int code) => (i, code),
);

int _seed(int day, int state, int trigger, int streak, int completed) =>
    VoiceSeed.compute(
      epochDay: day,
      state: GhostState.values[state],
      trigger: VoiceTrigger.values[trigger],
      streak: streak,
      completedToday: completed,
    );

void main() {
  group('VoiceSeed range and web safety (Property 6)', () {
    // Feature: ghost-voice, Property 6: Seed range and web safety
    // Validates: Requirements 7.1, 7.2, 12.2, 12.4
    Glados(_anyInputs, ExploreConfig(numRuns: _numRuns)).test(
      'the seed is an integer in 0..4294967290',
      (_Inputs input) {
        final (day, state, trigger, streak, completed) = input;
        _rangeRuns.increment();
        expect(
          _seed(day, state, trigger, streak, completed),
          inInclusiveRange(0, _maxSeed),
        );
      },
    );

    test('every property body ran numRuns times', () {
      _rangeRuns.expectRuns(_numRuns);
    });

    // Feature: ghost-voice, Property 6: Seed range and web safety
    // Validates: Requirements 7.2, 12.4
    Glados(
      anyIntBetween(0, _maxSeed + 1),
      ExploreConfig(numRuns: _numRuns),
    ).test('h * 1000003 stays below 2^53 for every h up to 4294967290', (
      int h,
    ) {
      _productRuns.increment();
      expect(h * _base, lessThan(_twoToThe53));
      expect(h * _base + _maxSeed, lessThan(_twoToThe53));
    });

    test('the product bound holds at the largest h', () {
      expect(_maxSeed * _base + _maxSeed, lessThan(_twoToThe53));
    });

    test('every product property body ran numRuns times', () {
      _productRuns.expectRuns(_numRuns);
    });
  });

  group('VoiceSeed sensitivity (Property 7)', () {
    // Feature: ghost-voice, Property 7: Seed sensitivity
    // Validates: Requirements 7.3, 7.5, 12.2
    Glados(_anyPair, ExploreConfig(numRuns: _numRuns)).test(
      'changing one input changes the seed for nearly every pair',
      (_Pair pair) {
        final (input, code) = pair;
        final (day, state, trigger, streak, completed) = input;
        _sensitivityRuns.increment();
        final int which = code % 5;
        final int delta = 1 + (code ~/ 5) % 999;
        final int before = _seed(day, state, trigger, streak, completed);
        final int after = switch (which) {
          0 => _seed(day + delta, state, trigger, streak, completed),
          1 => _seed(
            day,
            (state + 1 + delta % (GhostState.values.length - 1)) %
                GhostState.values.length,
            trigger,
            streak,
            completed,
          ),
          2 => _seed(
            day,
            state,
            (trigger + 1 + delta % (VoiceTrigger.values.length - 1)) %
                VoiceTrigger.values.length,
            streak,
            completed,
          ),
          3 => _seed(day, state, trigger, streak + delta, completed),
          _ => _seed(day, state, trigger, streak, completed + 1 + delta % 12),
        };
        _pairs++;
        if (before != after) _changed++;
      },
    );

    test('at least 99 percent of the pairs gave a different seed', () {
      _sensitivityRuns.expectRuns(_numRuns);
      expect(_pairs, equals(_numRuns));
      expect(_changed * 100, greaterThanOrEqualTo(_pairs * 99));
    });
  });

  group('VoiceSeed stability (Property 8)', () {
    // Feature: ghost-voice, Property 8: Seed stability
    // Validates: Requirements 7.1, 12.2
    Glados(_anyInputs, ExploreConfig(numRuns: _numRuns)).test(
      'the same inputs give the same seed',
      (_Inputs input) {
        final (day, state, trigger, streak, completed) = input;
        _stabilityRuns.increment();
        final int first = _seed(day, state, trigger, streak, completed);
        final int second = _seed(day, state, trigger, streak, completed);
        expect(first, equals(second));
        expect(first == second, isTrue);
      },
    );

    test('every property body ran numRuns times', () {
      _stabilityRuns.expectRuns(_numRuns);
    });
  });
}
