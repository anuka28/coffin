// Feature: graveyard-resurrection, Property 9: Living_Split never throws and is deterministic
// Validates: Requirements 6.7, 6.8
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/living_split.dart';

import 'support/grave_generators.dart';

final RunCounter _playingCounter = RunCounter();
final RunCounter _listCounter = RunCounter();

/// Calls the split twice with the same arguments and asserts that neither
/// call throws and that both results are equal, list by list and in order.
void _expectDeterministic(List<Grave> graves, Set<String> playing) {
  late (List<Grave>, List<Grave>) first;
  late (List<Grave>, List<Grave>) second;
  expect(
    () => first = LivingSplit.split(graves: graves, playing: playing),
    returnsNormally,
  );
  expect(
    () => second = LivingSplit.split(graves: graves, playing: playing),
    returnsNormally,
  );
  expect(second.$1, orderedEquals(first.$1));
  expect(second.$2, orderedEquals(first.$2));
}

void main() {
  group('Property 9: Living_Split never throws and is deterministic', () {
    Glados(anyPlayingSet, ExploreConfig(numRuns: numRuns)).test(
      'same arguments give equal results for any playing set, including '
      'equal risenOn values',
      (PlayingCase c) {
        _playingCounter.increment();
        _expectDeterministic(c.graves, c.playing);
      },
    );

    Glados(anyGraveList, ExploreConfig(numRuns: numRuns)).test(
      'same arguments give equal results for any grave list',
      (List<Grave> graves) {
        _listCounter.increment();
        _expectDeterministic(graves, const <String>{});
      },
    );

    test('an empty list gives two empty lists, twice', () {
      for (final Set<String> playing in <Set<String>>[
        const <String>{},
        const <String>{'g1', 'unknown'},
      ]) {
        _expectDeterministic(const <Grave>[], playing);
        final (List<Grave> rows, List<Grave> living) = LivingSplit.split(
          graves: const <Grave>[],
          playing: playing,
        );
        expect(rows, isEmpty);
        expect(living, isEmpty);
      }
    });

    test('ran the configured number of times', () {
      _playingCounter.expectRuns(numRuns);
      _listCounter.expectRuns(numRuns);
    });
  });
}
