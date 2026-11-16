import '../../common/seeded_random.dart';
import 'fog_disc.dart';
import 'fog_particle.dart';
import 'ping_pong.dart';

/// A seeded set of slowly drifting fog blobs.
///
/// All per-particle parameters are drawn once in the constructor from one
/// [SeededRandom], so the first N particles of a field do not depend on the
/// requested count. Positions use [PingPong] with integer phases, so the
/// result is the same on the Dart VM and on Flutter Web.
final class FogField {
  /// Builds a field. [seed] is masked with 0xFFFFFFFF and [count] is clamped
  /// into 0..[maxCount].
  factory FogField({required int seed, int count = defaultCount}) {
    final int maskedSeed = seed & 0xFFFFFFFF;
    final int clamped = count < 0 ? 0 : (count > maxCount ? maxCount : count);
    final SeededRandom r = SeededRandom(maskedSeed);
    final List<_Spec> specs = <_Spec>[];
    for (int i = 0; i < clamped; i++) {
      final int ax = r.nextInt(1001);
      final int ay = r.nextInt(1001);
      int bx = r.nextInt(1001);
      final int by = r.nextInt(1001);
      final int dx = bx - ax;
      if ((dx < 0 ? -dx : dx) < 100) {
        bx = ax <= 500 ? ax + 300 : ax - 300;
      }
      final double radius = (350 + r.nextInt(251)) / 1000;
      final double alpha = (30 + r.nextInt(11)) / 1000;
      final int periodMs = minPeriodMs + 1000 * r.nextInt(61);
      final int startMs = r.nextUint32() % periodMs;
      specs.add(_Spec(ax, ay, bx, by, radius, alpha, periodMs, startMs));
    }
    return FogField._(maskedSeed, clamped, List<_Spec>.unmodifiable(specs));
  }

  const FogField._(this.seed, this.count, this._specs);

  /// Largest number of particles.
  static const int maxCount = 24;

  /// Number of particles when none is given.
  static const int defaultCount = 5;

  /// Shortest drift period, in milliseconds.
  static const int minPeriodMs = 30000;

  /// Longest drift period, in milliseconds.
  static const int maxPeriodMs = 90000;

  /// The seed after masking with 0xFFFFFFFF.
  final int seed;

  /// The particle count after clamping into 0..[maxCount].
  final int count;

  final List<_Spec> _specs;

  /// Exactly [count] particles at [elapsedMs]. Never throws.
  ///
  /// Negative times wrap with Dart's non-negative `%`.
  List<FogParticle> particlesAt(int elapsedMs) {
    return List<FogParticle>.unmodifiable(<FogParticle>[
      for (final _Spec s in _specs) s.at(elapsedMs),
    ]);
  }

  /// The particles of the static frame: `particlesAt(0)`.
  List<FogParticle> get staticParticles => particlesAt(0);

  /// Maps a unit particle to pixels inside a [width] by [height] box.
  ///
  /// The radius is a fraction of the longer side, so a blob is large on a
  /// wide or tall box. It is 0 when either side is 0.
  ///
  /// A dimension that is negative, NaN or infinite counts as 0. Unit values
  /// are clamped into 0..1, and NaN counts as 0.
  static FogDisc toBounds(FogParticle particle, double width, double height) {
    final double w = (width.isFinite && width >= 0) ? width : 0;
    final double h = (height.isFinite && height >= 0) ? height : 0;
    // A box with a zero side has no area to paint, so the radius is 0.
    final double longer = (w > 0 && h > 0) ? (w > h ? w : h) : 0;
    return FogDisc(
      x: _unit(particle.x) * w,
      y: _unit(particle.y) * h,
      radius: _unit(particle.radius) * longer,
    );
  }

  static double _unit(double v) => v > 0 ? (v > 1 ? 1 : v) : 0;
}

final class _Spec {
  const _Spec(
    this.ax,
    this.ay,
    this.bx,
    this.by,
    this.radius,
    this.alpha,
    this.periodMs,
    this.startMs,
  );

  final int ax;
  final int ay;
  final int bx;
  final int by;
  final double radius;
  final double alpha;
  final int periodMs;
  final int startMs;

  FogParticle at(int elapsedMs) {
    final int phase = (elapsedMs + startMs) % periodMs;
    final double e = PingPong.at(phase, periodMs);
    return FogParticle(
      x: _thousandths(ax + (bx - ax) * e),
      y: _thousandths(ay + (by - ay) * e),
      radius: radius,
      alpha: alpha,
    );
  }

  static double _thousandths(double v) =>
      (v < 0 ? 0 : (v > 1000 ? 1000 : v)) / 1000;
}
