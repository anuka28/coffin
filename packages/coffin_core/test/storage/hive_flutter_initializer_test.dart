import 'package:coffin_core/src/storage/hive_flutter_initializer.dart';
import 'package:coffin_core/src/storage/storage_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hiveFlutterInitializer has the StorageInitializer shape', () {
    // Compile-time check only. Calling it needs path_provider, which is not
    // available on the test VM.
    const StorageInitializer init = hiveFlutterInitializer;
    expect(init, isNotNull);
  });
}
