import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/scene/thousands_formatter.dart';

void main() {
  group('ThousandsFormatter', () {
    test('formats the examples of Requirement 12.2', () {
      const cases = <int, String>{
        0: '0',
        7: '7',
        999: '999',
        1000: '1,000',
        60683: '60,683',
        181478: '181,478',
        1234567: '1,234,567',
      };
      cases.forEach((value, expected) {
        expect(ThousandsFormatter.format(value), expected, reason: '$value');
      });
    });

    test('formats a negative number as a minus and the absolute value', () {
      expect(ThousandsFormatter.format(-1234), '-1,234');
    });

    test('formats the largest integer below 2^53', () {
      // 0x1FFFFFFFFFFFFF is 2^53 - 1, exactly representable on web.
      expect(
        ThousandsFormatter.format(0x1FFFFFFFFFFFFF),
        '9,007,199,254,740,991',
      );
    });
  });
}
