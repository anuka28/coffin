/// The tiny storage surface the engine needs: String values by String key.
abstract interface class RawStore {
  /// The stored string, or null when absent.
  Future<String?> read(String key);

  /// Every stored key, in any order. Non-String keys are not reported.
  Future<List<String>> keys();

  /// Stores [value] under [key], overwriting.
  Future<void> write(String key, String value);

  /// Removes [key]. Returns whether it existed.
  Future<bool> remove(String key);

  /// Removes everything.
  Future<void> removeAll();

  /// Releases the store. Persistent stores keep their data.
  Future<void> close();
}
