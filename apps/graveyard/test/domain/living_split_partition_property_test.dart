// Feature: graveyard-resurrection, Property 8: Living_Split is a partition
// Validates: Requirements 6.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/living_split.dart';

import 'support/grave_generators.dart';

final RunCounter _playingCounter = RunCounter();
final RunCounter _listCounter = RunCounter();

/// Asserts that every grave of [input] is in exactly one of the two lists and
/// that the lists together hold [input] as a multiset.
void _expectPartition(List<Grave> input, (List<Grave>, List<Grave>) result) {
  final List<Grave> graveyardRows = result.$1;
  final List<Grave> livingRow = result.$2;

  expect(graveyardRows.length + livingRow.length, equals(input.length));

  for (final Grave g in input) {
    final int inGraveyard = graveyardRows.where((Grave x) => x == g).length;
    final int inLiving = livingRow.where((Grave x) => x == g).length;
    final int inInput = input.where((Grave x) => x == g).length;
    expect(inGraveyard + inLiving, equals(inInput), reason: 'multiset of $g');
    expect(
      inGraveyard == 0 || inLiving == 0,
      isTrue,
      reason: '$g appears in both lists',
    );
  }
  for (final Grave g in <Grave>[...graveyardRows, ...livingRow]) {
    expect(input.contains(g), isTrue, reason: '$g was not in the input');
  }
}

void main() {
  group('Property 8: Living_Split is a partition', () {
    Glados(anyPlayingSet, ExploreConfig(numRuns: numRuns)).test(
      'every grave is in exactly one list for any playing set',
      (PlayingCase c) {
        _playingCounter.increment();
        _expectPartition(
          c.graves,
          LivingSplit.split(graves: c.graves, playing: c.playing),
        );
      },
    );

    Glados(anyGraveList, ExploreConfig(numRuns: numRuns)).test(
      'every grave is in exactly one list for any grave list',
      (List<Grave> graves) {
        _listCounter.increment();
        _expectPartition(
          graves,
          LivingSplit.split(graves: graves, playing: const <String>{}),
        );
      },
    );

    test('ran the configured number of times', () {
      _playingCounter.expectRuns(numRuns);
      _listCounter.expectRuns(numRuns);
    });
  });
}
