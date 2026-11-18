import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/data/system_clock.dart';

void main() {
  test('SystemClock returns a local DateTime close to now', () {
    final DateTime before = DateTime.now();
    final DateTime value = const SystemClock().now();
    final DateTime after = DateTime.now();

    expect(value.isUtc, isFalse);
    expect(value.isBefore(before), isFalse);
    expect(value.isAfter(after), isFalse);
  });
}
