import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/system_clock.dart';

void main() {
  test('now() is close to DateTime.now() and is not UTC', () {
    final before = DateTime.now();
    final value = const SystemClock().now();
    final after = DateTime.now();
    expect(value.isUtc, isFalse);
    expect(
      value.isBefore(before.subtract(const Duration(seconds: 5))),
      isFalse,
    );
    expect(value.isAfter(after.add(const Duration(seconds: 5))), isFalse);
  });
}
