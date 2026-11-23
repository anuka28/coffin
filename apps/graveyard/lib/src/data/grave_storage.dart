import 'package:coffin_core/coffin_core.dart';

import '../domain/grave.dart';
import 'grave_codec.dart';

/// Opens the repository that stores the graves.
abstract final class GraveStorage {
  /// The name of the box that holds the graves.
  static const String boxName = 'graveyard_graves';

  /// The current version of the stored grave envelope.
  static const int currentVersion = 1;

  /// The sub-directory under the app storage location used on the VM.
  static const String subDirectory = 'graveyard';

  /// Opens the persistent grave repository with [opener].
  ///
  /// Falls back to memory when storage cannot be opened, as [opener] decides.
  static Future<OpenedRepository<Grave>> open(StorageOpener opener) {
    return opener.open<Grave>(
      boxName: boxName,
      codec: const GraveCodec(),
      currentVersion: currentVersion,
    );
  }

  /// Creates a grave repository that keeps data in memory only.
  static OpenedRepository<Grave> memory() {
    return OpenedRepository<Grave>(
      repository: MemoryRecordRepository<Grave>(
        codec: const GraveCodec(),
        currentVersion: currentVersion,
      ),
      isPersistent: false,
    );
  }
}
