import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/rate_limit_wait.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  test('30 seconds rounds up to 1 minute', () {
    expect(
      RateLimitWait.minutes(
        resetAt: now.add(const Duration(seconds: 30)),
        now: now,
      ),
      1,
    );
  });

  test('61 seconds rounds up to 2 minutes', () {
    expect(
      RateLimitWait.minutes(
        resetAt: now.add(const Duration(seconds: 61)),
        now: now,
      ),
      2,
    );
  });

  test('exactly 60 seconds is 1 minute', () {
    expect(
      RateLimitWait.minutes(
        resetAt: now.add(const Duration(seconds: 60)),
        now: now,
      ),
      1,
    );
  });

  test('a reset in the past is 1 minute', () {
    expect(
      RateLimitWait.minutes(
        resetAt: now.subtract(const Duration(hours: 1)),
        now: now,
      ),
      1,
    );
  });
}
