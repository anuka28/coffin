import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/grave_list_status.dart';
import 'package:graveyard/src/ui/save_status.dart';

void main() {
  test('GraveListStatus has loading, ready and loadError in order', () {
    expect(GraveListStatus.values, [
      GraveListStatus.loading,
      GraveListStatus.ready,
      GraveListStatus.loadError,
    ]);
  });

  test('SaveStatus has saved, saving and saveError in order', () {
    expect(SaveStatus.values, [
      SaveStatus.saved,
      SaveStatus.saving,
      SaveStatus.saveError,
    ]);
  });
}
