import 'package:coffin_core/coffin_core.dart';

import '../domain/calendar_date.dart';
import '../domain/grave.dart';
import '../domain/grave_source.dart';
import '../domain/name_rules.dart';
import '../domain/repo_info.dart';

/// Turns a [Grave] into a JSON-safe map and back.
///
/// Encoding uses a fixed key order and writes the date as `YYYY-MM-DD`. A
/// manual grave has no `repo` key. Decoding throws [FormatException] for a
/// missing or invalid field, defaults the optional repository fields and
/// ignores unknown keys.
final class GraveCodec implements RecordCodec<Grave> {
  /// Creates a grave codec.
  const GraveCodec();

  @override
  JsonMap encode(Grave value) {
    final RepoInfo? repo = value.repo;
    return <String, Object?>{
      'id': value.id,
      'name': value.name,
      'died': value.dateOfDeath.toIso(),
      'source': value.source.name,
      if (value.source == GraveSource.github && repo != null)
        'repo': <String, Object?>{
          'full_name': repo.fullName,
          'html_url': repo.htmlUrl,
          'description': repo.description,
          'archived': repo.archived,
          'stars': repo.stars,
        },
    };
  }

  @override
  Grave decode(JsonMap json) {
    final Object? rawId = json['id'];
    if (rawId is! String || !KeyValidator.isValid(rawId)) {
      throw const FormatException('Grave id is missing or invalid.');
    }
    final Object? rawName = json['name'];
    if (rawName is! String) {
      throw const FormatException('Grave name is missing or not text.');
    }
    final String name = NameRules.normalize(rawName);
    final int length = NameRules.length(name);
    if (length < 1 || length > NameRules.maxLength) {
      throw const FormatException('Grave name has an unusable length.');
    }
    final Object? rawDied = json['died'];
    final CalendarDate? died = rawDied is String
        ? CalendarDate.tryParse(rawDied)
        : null;
    if (died == null) {
      throw const FormatException('Grave date is missing or not a real date.');
    }
    final Object? source = json['source'];
    if (source == GraveSource.manual.name) {
      return Grave.manual(id: rawId, name: name, dateOfDeath: died);
    }
    if (source != GraveSource.github.name) {
      throw const FormatException('Grave source is unknown.');
    }
    final Object? rawRepo = json['repo'];
    final Map<Object?, Object?> repo = rawRepo is Map ? rawRepo : const {};
    final Object? fullName = repo['full_name'];
    final Object? htmlUrl = repo['html_url'];
    final Object? description = repo['description'];
    final Object? archived = repo['archived'];
    final Object? stars = repo['stars'];
    return Grave.github(
      id: rawId,
      name: name,
      dateOfDeath: died,
      repo: RepoInfo(
        fullName: fullName is String && fullName.isNotEmpty ? fullName : name,
        htmlUrl: htmlUrl is String ? htmlUrl : null,
        description: description is String ? description : null,
        archived: archived is bool ? archived : false,
        stars:
            stars is num &&
                stars.isFinite &&
                stars >= 0 &&
                stars == stars.truncate()
            ? stars.toInt()
            : 0,
      ),
    );
  }
}
