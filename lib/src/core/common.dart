/// This error is used to explain why parsing failed.
class ParsingError<T> implements Exception {
  /// The error message that describes the issue.
  final String message;

  /// This provides a programmatic way to access why parsing failed. Downstream
  /// devs might want to use this to build their own error messages if the
  /// default error messages are not suitable for their use case.
  final T invalidReason;

  ParsingError(this.message, this.invalidReason);

  @override
  String toString() => 'ParsingError($invalidReason): $message';
}

/// Whereas [ParsingError] is thrown when parsing fails, e.g. in a fromString
/// function, this type is returned from "defensive" functions like isValid.
class ParsingResult<T> {
  /// True if valid, false otherwise.
  final bool valid;

  /// If valid is false, this will be a code explaining why parsing failed.
  final T? invalidReason;

  /// If valid is false, this will be a string explaining why parsing failed.
  final String? invalidReasonMessage;

  const ParsingResult({
    required this.valid,
    this.invalidReason,
    this.invalidReasonMessage,
  });
}
