import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/star.dart';

Star _star({
  double dx = 1,
  double dy = 2,
  double radius = 1.5,
  int phaseMs = 100,
  int periodMs = 4000,
}) =>
    Star(dx: dx, dy: dy, radius: radius, phaseMs: phaseMs, periodMs: periodMs);

void main() {
  group('Star', () {
    test('equal stars are equal and share a hashCode', () {
      expect(_star(), _star());
      expect(_star().hashCode, _star().hashCode);
    });

    test('a different field breaks equality', () {
      expect(_star(), isNot(_star(dx: 3)));
      expect(_star(), isNot(_star(dy: 3)));
      expect(_star(), isNot(_star(radius: 2)));
      expect(_star(), isNot(_star(phaseMs: 101)));
      expect(_star(), isNot(_star(periodMs: 4001)));
    });

    test('toString names the fields', () {
      // A fractional value prints the same on the VM and on the web, where
      // 1.0 prints as "1".
      expect(_star(dx: 1.5).toString(), contains('dx: 1.5'));
    });
  });
}
