import 'package:coffin_raise/src/names/name_suggester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NameSuggester', () {
    test('Bone-Shop suggests bone_shop', () {
      expect(NameSuggester.suggest('Bone-Shop'), 'bone_shop');
    });

    test('fixes dots, separators and spaces', () {
      expect(NameSuggester.suggest('bone.shop'), 'bone_shop');
      expect(NameSuggester.suggest('bone/shop'), 'bone_shop');
    });

    test('fixes digits, reserved words and edge underscores', () {
      expect(NameSuggester.suggest('2spooky'), 'app_2spooky');
      expect(NameSuggester.suggest('class'), 'class_app');
      expect(NameSuggester.suggest('__a  b__'), 'a_b');
    });

    test('returns null when nothing can be derived', () {
      expect(NameSuggester.suggest(''), isNull);
      expect(NameSuggester.suggest('!!!'), isNull);
      expect(NameSuggester.suggest('bone', takenNames: {'bone'}), isNull);
    });
  });
}
