// Feature: graveyard-scene, Property 18: Visible text fragments are unique
// Validates: Requirements 10.1, 10.3, 10.4, 10.5, 10.10
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_source.dart';
import 'package:graveyard/src/domain/scene/tombstone_facts.dart';
import 'package:graveyard/src/domain/scene/tombstone_fragment.dart';
import 'package:graveyard/src/domain/scene/tombstone_fragment_kind.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 18: Visible text fragments are unique', () {
    Glados3(
      anyGrave,
      anyDateLine,
      anyCalendarDate,
      ExploreConfig(numRuns: numRuns),
    ).test(
      'each kind appears at most once, in display order, and the full name '
      'only for a GitHub grave with a different full_name',
      (Grave grave, String dateLine, CalendarDate today) {
        _counter.increment();
        final List<TombstoneFragment> fragments = TombstoneFacts.of(
          grave: grave,
          today: today,
          dateLine: dateLine,
        );
        final List<TombstoneFragmentKind> kinds = <TombstoneFragmentKind>[
          for (final TombstoneFragment f in fragments) f.kind,
        ];

        // No two fragments share a kind.
        expect(kinds.toSet().length, kinds.length);
        for (final TombstoneFragmentKind kind in TombstoneFragmentKind.values) {
          expect(
            kinds.where((TombstoneFragmentKind k) => k == kind).length,
            lessThanOrEqualTo(1),
          );
        }

        // Title, date line and dead-for are always first, in that order.
        expect(kinds.length, greaterThanOrEqualTo(3));
        expect(kinds.take(3).toList(), <TombstoneFragmentKind>[
          TombstoneFragmentKind.title,
          TombstoneFragmentKind.dateLine,
          TombstoneFragmentKind.deadFor,
        ]);
        expect(fragments[0].text, grave.name);
        expect(fragments[1].text, dateLine);

        // The full name shows only for a GitHub grave with a different name.
        final repo = grave.repo;
        final bool expectFullName =
            grave.source == GraveSource.github &&
            repo != null &&
            repo.fullName != grave.name;
        expect(kinds.contains(TombstoneFragmentKind.fullName), expectFullName);
        expect(kinds.length, expectFullName ? 4 : 3);
        if (expectFullName) {
          expect(fragments[3].kind, TombstoneFragmentKind.fullName);
          expect(fragments[3].text, repo.fullName);
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
