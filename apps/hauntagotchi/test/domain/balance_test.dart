import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/balance.dart';

void main() {
  test('constants have the designed values', () {
    expect(Balance.maxHealth, 100);
    expect(Balance.fullFeed, 20);
    expect(Balance.neglectLoss, 15);
    expect(Balance.freshStartHealth, 40);
    expect(Balance.candlesNeeded, 2);
    expect(Balance.qualifyingPercent, 60);
    expect(Balance.defaultGhostName, 'Wisp');
  });

  group('feed(n, c) table', () {
    const table = <int, List<int>>{
      1: [20],
      2: [10, 20],
      3: [6, 13, 20],
      4: [5, 10, 15, 20],
      5: [4, 8, 12, 16, 20],
    };
    table.forEach((n, values) {
      test('n=$n', () {
        final actual = [for (var c = 1; c <= n; c++) Balance.feed(n, c)];
        expect(actual, values);
      });
    });
  });
}
