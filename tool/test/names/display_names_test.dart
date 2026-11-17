import 'package:coffin_raise/src/names/display_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DisplayNames', () {
    test('derives display and class names', () {
      expect(DisplayNames.displayName('bone_shop'), 'Bone Shop');
      expect(DisplayNames.className('bone_shop'), 'BoneShop');
      expect(DisplayNames.displayName('crypt'), 'Crypt');
      expect(DisplayNames.className('app_2spooky'), 'App2spooky');
    });
  });
}
