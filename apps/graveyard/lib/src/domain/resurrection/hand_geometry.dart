import 'hand_height.dart';
import 'hand_shape.dart';
import 'stone_point.dart';

/// Pure function from the Stone_Area size and elapsed milliseconds to the
/// Hand's bones.
abstract final class HandGeometry {
  /// Largest share of the stone height the Hand reaches above the ground line.
  static const double maxReachFraction = 0.35;

  /// Half the Hand's width as a share of the stone width.
  static const double halfWidthFraction = 0.15;

  // Heights are shares of the reach above the ground line (0 to 1), and
  // sideways offsets are shares of the half width from the stone's center.
  // The wrist sits at 0.4; the middle fingertip is the top at exactly 1.
  static const double _wristRise = 0.4;

  // Each finger: knuckle, middle joint and tip as (dx, rise), index to little.
  // Tips are pulled back toward the center (a claw) and the fingers fan out.
  static const List<List<(double, double)>> _fingers = <List<(double, double)>>[
    <(double, double)>[(-0.5, 0.65), (-0.8, 0.8), (-0.7, 0.94)], // index
    <(double, double)>[(-0.1, 0.7), (-0.15, 0.88), (-0.05, 1.0)], // middle
    <(double, double)>[(0.3, 0.66), (0.45, 0.82), (0.38, 0.95)], // ring
    <(double, double)>[(0.7, 0.6), (1.0, 0.72), (0.92, 0.82)], // little
  ];

  // Thumb: starts low on the left of the palm and angles outward.
  static const List<(double, double)> _thumb = <(double, double)>[
    (-0.2, 0.3),
    (-0.8, 0.4),
    (-1.2, 0.5),
    (-1.3, 0.6),
  ];

  /// Returns the Hand's bones [elapsedMs] milliseconds into the play.
  ///
  /// When visible there are 7 bones: two forearm bones (ground line to
  /// wrist), four fingers and the thumb, each finger a polyline of 4 points
  /// (wrist, knuckle, middle joint, tip). The result is an invisible, empty
  /// shape while [HandHeight.at] is 0 or when [width] or [height] is not
  /// finite and positive. Otherwise every point lies in
  /// `[0, width] x [0, height]`.
  static HandShape at({
    required double width,
    required double height,
    required int elapsedMs,
  }) {
    const HandShape hidden = HandShape(
      bones: <List<StonePoint>>[],
      visible: false,
    );
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return hidden;
    }
    final double h = HandHeight.at(elapsedMs);
    if (h <= 0) return hidden;
    final double cx = width / 2;
    final double half = width * halfWidthFraction;
    final double reach = height * maxReachFraction * h;
    StonePoint pt((double, double) p) =>
        StonePoint(cx + half * p.$1, height - reach * p.$2);
    final StonePoint wrist = pt((0, _wristRise));
    return HandShape(
      visible: true,
      bones: <List<StonePoint>>[
        <StonePoint>[
          StonePoint(cx - half * 0.3, height),
          pt((-0.25, _wristRise)),
        ],
        <StonePoint>[
          StonePoint(cx + half * 0.3, height),
          pt((0.25, _wristRise)),
        ],
        for (final List<(double, double)> f in _fingers)
          <StonePoint>[wrist, for (final (double, double) j in f) pt(j)],
        <StonePoint>[for (final (double, double) j in _thumb) pt(j)],
      ],
    );
  }
}
