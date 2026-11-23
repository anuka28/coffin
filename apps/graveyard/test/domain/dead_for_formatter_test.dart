import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';

void main() {
  final today = CalendarDate(2025, 6, 15);

  test('format gives the text of DeadFor.between', () {
    final deaths = [
      today,
      today.addDays(1),
      today.addDays(-1),
      today.addDays(-6),
      today.addDays(-7),
      today.addDays(-45),
      today.addMonthsClamped(-1),
      today.addMonthsClamped(-12),
      today.addMonthsClamped(-30),
    ];
    for (final death in deaths) {
      expect(
        DeadForFormatter.format(death, today),
        DeadFor.between(death, today).text,
        reason: 'death $death',
      );
    }
  });

  test('format gives known texts', () {
    expect(DeadForFormatter.format(today, today), 'Died today');
    expect(DeadForFormatter.format(today.addDays(-1), today), 'Dead for 1 day');
    expect(
      DeadForFormatter.format(today.addMonthsClamped(-12), today),
      'Dead for 1 year',
    );
  });
}
