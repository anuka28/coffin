import 'package:coffin_core/src/widgets/math/mouth_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MouthStyle.values lists the styles in the expected order', () {
    expect(MouthStyle.values, const [
      MouthStyle.none,
      MouthStyle.smile,
      MouthStyle.gentleSmile,
      MouthStyle.wideSmile,
      MouthStyle.smallOpen,
      MouthStyle.flat,
    ]);
  });
}
