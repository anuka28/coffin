import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/add_mode.dart';

void main() {
  test('AddMode has the two ways to add a grave', () {
    expect(AddMode.values, <AddMode>[
      AddMode.buryByHand,
      AddMode.importFromGitHub,
    ]);
  });
}
