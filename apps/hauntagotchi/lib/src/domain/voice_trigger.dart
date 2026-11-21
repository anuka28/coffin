/// The four moments that may change Wisp's voice line.
///
/// The [name] of each value is the Event_Fact value sent to the AI layer, so
/// the names are a contract with `coffin_core` and must not be renamed.
enum VoiceTrigger {
  /// The home screen finished loading and shows the ghost.
  ///
  /// The `name` is the Event_Fact value `appOpened`.
  appOpened,

  /// A habit was completed for today (not undone).
  ///
  /// The `name` is the Event_Fact value `checkedOff`.
  checkedOff,

  /// The ghost's steady mood changed without a check-off or resurrection.
  ///
  /// The `name` is the Event_Fact value `moodChanged`.
  moodChanged,

  /// A ritual completed and the ghost came back.
  ///
  /// The `name` is the Event_Fact value `resurrected`.
  resurrected,
}
