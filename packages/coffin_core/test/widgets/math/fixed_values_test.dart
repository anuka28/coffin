import 'package:coffin_core/src/widgets/math/flicker_schedule.dart';
import 'package:coffin_core/src/widgets/math/fog_field.dart';
import 'package:coffin_core/src/widgets/math/ghost_bob.dart';
import 'package:flutter_test/flutter_test.dart';

// Independent BigInt reference of Mulberry32.
final BigInt _m32 = BigInt.from(0xFFFFFFFF);

class _Ref {
  _Ref(int seed) : _a = BigInt.from(seed) & _m32;

  BigInt _a;

  BigInt next() {
    _a = (_a + BigInt.from(0x6D2B79F5)) & _m32;
    BigInt t = ((_a ^ (_a >> 15)) * (_a | BigInt.one)) & _m32;
    t = (((t + ((t ^ (t >> 7)) * (t | BigInt.from(61)))) & _m32) ^ t);
    return (t ^ (t >> 14)) & _m32;
  }

  int below(int n) => (next() % BigInt.from(n)).toInt();
}

/// Converts the exact fraction num/den to a double (error below 1e-17).
double _ratio(BigInt num, BigInt den) {
  final BigInt scale = BigInt.from(10).pow(18);
  return (num * scale ~/ den).toDouble() / 1e18;
}

/// Exact smoothstep ping-pong as a fraction n^2 (3P - 2n) / P^3.
(BigInt, BigInt) _pingPongFraction(int phase, int period) {
  BigInt n = BigInt.from(2 * phase);
  final BigInt p = BigInt.from(period);
  if (n > p) n = BigInt.two * p - n;
  return (n * n * (BigInt.from(3) * p - BigInt.two * n), p * p * p);
}

List<int> _refFlicker(int seed) {
  final r = _Ref(seed);
  final List<int> v = <int>[for (int i = 0; i < 16; i++) 75 + r.below(26)];
  int mi = 0;
  for (int i = 1; i < 16; i++) {
    if (v[i] < v[mi]) mi = i;
  }
  if (v[mi] > 90) v[mi] = 85;
  int xi = 0;
  for (int i = 1; i < 16; i++) {
    if (v[i] > v[xi]) xi = i;
  }
  if (v[xi] != 100) v[xi] = 100;
  return v;
}

class _RefParticle {
  const _RefParticle(
    this.ax,
    this.ay,
    this.bx,
    this.by,
    this.radius,
    this.alpha,
    this.period,
    this.start,
  );

  final int ax, ay, bx, by, period, start;
  final double radius, alpha;

  List<int> get params => <int>[ax, ay, bx, by, period, start];

  /// Position at `t` ms from exact rational arithmetic.
  (double, double) at(int t) {
    final (BigInt num, BigInt den) = _pingPongFraction(
      (t + start) % period,
      period,
    );
    double coord(int a, int b) {
      final BigInt n =
          BigInt.from(a) * den + BigInt.from(b - a) * num; // times 1/1000
      return _ratio(n, den * BigInt.from(1000));
    }

    return (coord(ax, bx), coord(ay, by));
  }
}

List<_RefParticle> _refFog(int seed, int count) {
  final r = _Ref(seed);
  return <_RefParticle>[
    for (int i = 0; i < count; i++)
      () {
        final int ax = r.below(1001);
        final int ay = r.below(1001);
        int bx = r.below(1001);
        final int by = r.below(1001);
        if ((bx - ax).abs() < 100) bx = ax <= 500 ? ax + 300 : ax - 300;
        final double radius = (350 + r.below(251)) / 1000;
        final double alpha = (30 + r.below(11)) / 1000;
        final int period = 30000 + 1000 * r.below(61);
        final int start = (r.next() % BigInt.from(period)).toInt();
        return _RefParticle(ax, ay, bx, by, radius, alpha, period, start);
      }(),
  ];
}

const List<int> _seeds = <int>[0, 1, 42, 4294967295];

/// Pinned flicker levels in percent, 16 per seed.
const Map<int, List<int>> _pinnedLevels = <int, List<int>>{
  0: [93, 76, 91, 83, 93, 80, 78, 81, 80, 87, 100, 80, 96, 88, 79, 89],
  1: [90, 92, 82, 82, 92, 95, 95, 79, 89, 100, 87, 83, 88, 91, 83, 79],
  42: [97, 77, 85, 86, 87, 100, 81, 82, 95, 80, 76, 94, 82, 83, 90, 95],
  4294967295: [94, 79, 81, 89, 88, 86, 98, 98, 90, 96, 82, 93, 75, 94, 88, 100],
};

/// (ax, ay, bx, by, periodMs, startMs, radius, alpha, x at 0 ms, y at 0 ms).
typedef _Pin = (int, int, int, int, int, int, double, double, double, double);

/// Pinned first particles of FogField(seed: s, count: 10), index order.
const Map<int, List<_Pin>> _pinnedParticles = <int, List<_Pin>>{
  0: <_Pin>[
    (
      577,
      833,
      68,
      138,
      46000,
      982,
      0.422,
      0.034,
      0.5742956347789121,
      0.8293073991578466,
    ),
    (
      486,
      636,
      786,
      980,
      31000,
      9798,
      0.514,
      0.034,
      0.6940740328944446,
      0.8745915577189631,
    ),
    (
      267,
      29,
      567,
      925,
      85000,
      82102,
      0.59,
      0.036,
      0.27099444162833036,
      0.0409300656632801,
    ),
    (
      891,
      701,
      196,
      110,
      47000,
      44274,
      0.594,
      0.03,
      0.86511388544,
      0.678987491072,
    ),
    (
      83,
      581,
      402,
      867,
      49000,
      5306,
      0.56,
      0.034,
      0.12140561327916034,
      0.6154326188020058,
    ),
    (
      449,
      345,
      134,
      746,
      75000,
      8735,
      0.519,
      0.038,
      0.4056884926530133,
      0.4001362363369576,
    ),
    (
      101,
      114,
      401,
      60,
      65000,
      32793,
      0.493,
      0.04,
      0.40092729020312645,
      0.060013087763437244,
    ),
    (
      282,
      662,
      792,
      13,
      89000,
      9489,
      0.595,
      0.032,
      0.3416787832903021,
      0.5860558228325372,
    ),
    (
      15,
      167,
      855,
      817,
      57000,
      10604,
      0.473,
      0.04,
      0.27732584482689865,
      0.3699902370684335,
    ),
    (
      17,
      563,
      511,
      504,
      53000,
      28693,
      0.406,
      0.036,
      0.501410687312792,
      0.5051452822845046,
    ),
  ],
  1: <_Pin>[
    (
      496,
      95,
      683,
      449,
      39000,
      21220,
      0.429,
      0.038,
      0.6788919958532006,
      0.441223350438679,
    ),
    (
      27,
      554,
      181,
      606,
      46000,
      38962,
      0.446,
      0.034,
      0.061434826272000004,
      0.565627343936,
    ),
    (
      276,
      384,
      874,
      472,
      89000,
      55523,
      0.389,
      0.039,
      0.7820998065726774,
      0.45847622571638064,
    ),
    (
      361,
      691,
      261,
      410,
      57000,
      33958,
      0.365,
      0.038,
      0.27059794272213744,
      0.4369702190492062,
    ),
    (
      577,
      788,
      277,
      788,
      74000,
      14732,
      0.563,
      0.036,
      0.47219333424477916,
      0.788,
    ),
    (
      601,
      930,
      301,
      13,
      90000,
      15687,
      0.502,
      0.03,
      0.5170477691536001,
      0.673386014379504,
    ),
    (
      983,
      962,
      513,
      856,
      67000,
      12039,
      0.39,
      0.035,
      0.8445277768067179,
      0.9307700943436428,
    ),
    (
      444,
      503,
      744,
      128,
      35000,
      27896,
      0.574,
      0.038,
      0.5521735455126018,
      0.36778306810924777,
    ),
    (
      334,
      961,
      73,
      643,
      56000,
      24543,
      0.568,
      0.038,
      0.08395319155929545,
      0.6563452678768428,
    ),
    (
      445,
      560,
      910,
      276,
      46000,
      38937,
      0.537,
      0.034,
      0.549619942323604,
      0.49610308898945477,
    ),
  ],
  42: <_Pin>[
    (
      815,
      821,
      49,
      193,
      79000,
      22857,
      0.514,
      0.031,
      0.3423672710325613,
      0.43351520392747844,
    ),
    (
      839,
      746,
      539,
      214,
      69000,
      24774,
      0.422,
      0.037,
      0.5970844502718501,
      0.31700309181541414,
    ),
    (
      132,
      813,
      865,
      994,
      61000,
      34488,
      0.425,
      0.036,
      0.8306816783327856,
      0.985525762316827,
    ),
    (
      812,
      977,
      482,
      51,
      57000,
      45939,
      0.388,
      0.04,
      0.7014632542341216,
      0.6668271921842321,
    ),
    (
      260,
      1,
      43,
      84,
      79000,
      15742,
      0.41,
      0.03,
      0.18407454929879044,
      0.030040610176038682,
    ),
    (
      240,
      886,
      756,
      574,
      36000,
      29793,
      0.377,
      0.037,
      0.38175644923477775,
      0.8002867981371111,
    ),
    (
      256,
      367,
      502,
      989,
      81000,
      35793,
      0.475,
      0.04,
      0.4928037704160658,
      0.9657477447105405,
    ),
    (
      759,
      579,
      198,
      68,
      55000,
      47459,
      0.473,
      0.033,
      0.6555814305414569,
      0.48479877184792247,
    ),
    (
      501,
      364,
      14,
      379,
      90000,
      83704,
      0.518,
      0.037,
      0.4750683195811826,
      0.36479871705602107,
    ),
    (
      215,
      751,
      736,
      413,
      37000,
      34821,
      0.554,
      0.039,
      0.23498088436700879,
      0.7380373533281209,
    ),
  ],
  4294967295: <_Pin>[
    (
      552,
      927,
      214,
      781,
      54000,
      16601,
      0.483,
      0.033,
      0.3257942543498184,
      0.8292898258434127,
    ),
    (
      626,
      125,
      20,
      5,
      77000,
      35920,
      0.489,
      0.033,
      0.02779942932766744,
      0.00654444145102326,
    ),
    (
      634,
      230,
      334,
      205,
      70000,
      19576,
      0.445,
      0.039,
      0.4574337785885854,
      0.21528614821571546,
    ),
    (
      520,
      430,
      405,
      132,
      83000,
      50882,
      0.517,
      0.038,
      0.41997501563270745,
      0.17080482311779838,
    ),
    (
      63,
      737,
      196,
      713,
      82000,
      69674,
      0.549,
      0.034,
      0.09183433435786456,
      0.7317968118451973,
    ),
    (
      547,
      61,
      737,
      768,
      72000,
      18912,
      0.442,
      0.034,
      0.6492138218192592,
      0.44134301066429626,
    ),
    (
      447,
      415,
      223,
      765,
      82000,
      7429,
      0.558,
      0.033,
      0.4276022408743906,
      0.4453089986337648,
    ),
    (
      556,
      643,
      741,
      603,
      74000,
      62549,
      0.559,
      0.034,
      0.5981909626636158,
      0.6338776296943534,
    ),
    (
      575,
      740,
      963,
      506,
      51000,
      1261,
      0.54,
      0.036,
      0.5777526053104247,
      0.7383399236014448,
    ),
    (
      471,
      875,
      585,
      581,
      78000,
      17973,
      0.352,
      0.035,
      0.5213183777279071,
      0.7452315521753974,
    ),
  ],
};

const List<double> _pinnedBob = <double>[0.0, 6.0, 0.0, -6.0, 0.0];

void main() {
  group('flicker levels', () {
    for (final int seed in _seeds) {
      test('seed $seed: lib equals the BigInt reference', () {
        final List<int> ref = _refFlicker(seed);
        expect(<int>[
          for (final double l in FlickerSchedule(seed).levels)
            (l * 100).round(),
        ], ref);
        expect(FlickerSchedule(seed).levels, <double>[
          for (final int p in ref) p / 100,
        ]);
      });
    }

    test('opacityAt matches the exact fraction', () {
      for (final int seed in _seeds) {
        final List<int> v = _refFlicker(seed);
        final FlickerSchedule f = FlickerSchedule(seed);
        for (final int t in <int>[0, 1, 199, 400, 2750, 6399, 6400, 12801]) {
          final int phase = t % 6400;
          final int seg = phase ~/ 400;
          final BigInt w = BigInt.from(phase - seg * 400);
          final BigInt s = w * w * (BigInt.from(1200) - BigInt.two * w);
          final BigInt a = BigInt.from(v[seg]);
          final BigInt b = BigInt.from(v[(seg + 1) % 16]);
          final BigInt num = a * BigInt.from(64000000) + (b - a) * s;
          expect(
            f.opacityAt(t),
            closeTo(_ratio(num, BigInt.from(6400000000)), 1e-12),
            reason: 'seed $seed t $t',
          );
        }
      }
    });
  });

  group('fog field', () {
    for (final int seed in _seeds) {
      test('seed $seed: particlesAt matches the exact reference', () {
        final List<_RefParticle> ref = _refFog(seed, 10);
        final field = FogField(seed: seed, count: 10);
        for (final int t in <int>[0, 7777, 45000]) {
          final particles = field.particlesAt(t);
          expect(particles.length, 10);
          for (int i = 0; i < 10; i++) {
            final (double x, double y) = ref[i].at(t);
            expect(particles[i].x, closeTo(x, 1e-12), reason: 'x $i t $t');
            expect(particles[i].y, closeTo(y, 1e-12), reason: 'y $i t $t');
            expect(particles[i].radius, ref[i].radius);
            expect(particles[i].alpha, ref[i].alpha);
          }
        }
      });
    }
  });

  group('ghost bob', () {
    test('lib equals the exact reference', () {
      final bob = GhostBob();
      for (final int t in <int>[0, 900, 1800, 2700, 3600, 1234]) {
        final (BigInt num, BigInt den) = _pingPongFraction(
          (t + 900) % 3600,
          3600,
        );
        final double ref = _ratio(
          BigInt.from(6) * (BigInt.two * num - den),
          den,
        );
        expect(bob.offsetAt(t), closeTo(ref, 1e-12), reason: 't $t');
      }
    });
  });

  group('pinned literals', () {
    for (final int seed in _seeds) {
      test('seed $seed: flicker levels equal the literals', () {
        expect(<int>[
          for (final double l in FlickerSchedule(seed).levels)
            (l * 100).round(),
        ], _pinnedLevels[seed]);
      });

      test('seed $seed: first particles equal literals and reference', () {
        final List<_RefParticle> ref = _refFog(seed, 10);
        final particles = FogField(seed: seed, count: 10).particlesAt(0);
        final List<_Pin> pins = _pinnedParticles[seed]!;
        expect(pins.length, 10);
        for (int i = 0; i < 10; i++) {
          final _Pin p = pins[i];
          expect(ref[i].params, <int>[p.$1, p.$2, p.$3, p.$4, p.$5, p.$6]);
          expect(ref[i].radius, p.$7);
          expect(ref[i].alpha, p.$8);
          expect(particles[i].x, p.$9, reason: 'x $i');
          expect(particles[i].y, p.$10, reason: 'y $i');
          expect(particles[i].radius, p.$7);
          expect(particles[i].alpha, p.$8);
        }
      });
    }

    test('seed 0 flicker starts 93, 76, 91, 83', () {
      expect(_pinnedLevels[0]!.take(4), <int>[93, 76, 91, 83]);
    });

    test('GhostBob offsets equal the literals', () {
      final bob = GhostBob();
      expect(<double>[
        for (final int t in <int>[0, 900, 1800, 2700, 3600]) bob.offsetAt(t),
      ], _pinnedBob);
    });
  });
}
