import 'package:coffin_core/src/router/fog_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = FogFrame(opacity: 0.5, dx: 0, dy: 8, blur: 4);

  test('equal fields give equal frames and hash codes', () {
    const same = FogFrame(opacity: 0.5, dx: 0, dy: 8, blur: 4);
    expect(base, same);
    expect(base.hashCode, same.hashCode);
  });

  test('any differing field breaks equality', () {
    expect(base, isNot(const FogFrame(opacity: 0.6, dx: 0, dy: 8, blur: 4)));
    expect(base, isNot(const FogFrame(opacity: 0.5, dx: 1, dy: 8, blur: 4)));
    expect(base, isNot(const FogFrame(opacity: 0.5, dx: 0, dy: 9, blur: 4)));
    expect(base, isNot(const FogFrame(opacity: 0.5, dx: 0, dy: 8, blur: 5)));
  });

  test('toString names every field', () {
    final text = base.toString();
    expect(text, contains('opacity'));
    expect(text, contains('dx'));
    expect(text, contains('dy'));
    expect(text, contains('blur'));
  });
}
