import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_source.dart';
import 'package:graveyard/src/domain/repo_info.dart';

void main() {
  final date = CalendarDate(2024, 1, 2);

  test('manual grave has no repo and value equality', () {
    final a = Grave.manual(id: 'g1', name: 'x', dateOfDeath: date);
    final b = Grave.manual(id: 'g1', name: 'x', dateOfDeath: date);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.source, GraveSource.manual);
    expect(a.repo, isNull);
  });

  test('github grave carries repo and compares it', () {
    const info = RepoInfo(fullName: 'a/b', stars: 3);
    final a = Grave.github(
      id: 'g1',
      name: 'a/b',
      dateOfDeath: date,
      repo: info,
    );
    final b = Grave.github(
      id: 'g1',
      name: 'a/b',
      dateOfDeath: date,
      repo: const RepoInfo(fullName: 'a/b', stars: 4),
    );
    expect(a.source, GraveSource.github);
    expect(a.repo, info);
    expect(a == b, isFalse);
  });
}
