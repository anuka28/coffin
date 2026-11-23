part of 'manual_grave_check.dart';

/// A by-hand grave that broke a rule.
final class ManualGraveRejected extends ManualGraveCheck {
  /// Creates a rejected result.
  const ManualGraveRejected(this.reason);

  /// The first rule that was broken.
  final GraveRejection reason;

  @override
  bool operator ==(Object other) =>
      other is ManualGraveRejected && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}
