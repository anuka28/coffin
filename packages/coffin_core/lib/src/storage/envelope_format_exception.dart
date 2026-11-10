/// Thrown when stored text is not a valid envelope.
///
/// The message is always a fixed reason string. It never contains any part of
/// the input, so it is safe to log or report.
final class EnvelopeFormatException extends FormatException {
  /// Creates an exception with a fixed [reason].
  const EnvelopeFormatException(super.reason);
}
