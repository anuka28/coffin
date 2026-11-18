import 'package:coffin_core/src/widgets/math/eye_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EyeStyle.values lists the styles in the expected order', () {
    expect(EyeStyle.values, const [
      EyeStyle.round,
      EyeStyle.wide,
      EyeStyle.droopy,
      EyeStyle.halfClosed,
      EyeStyle.cross,
      EyeStyle.happyArc,
    ]);
  });
}
