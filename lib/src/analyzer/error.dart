class MacroException implements Exception {
  MacroException([this.message]);

  final String? message;

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "MacroException";
    return "MacroException: $message";
  }
}

class InvalidDiscriminatorException implements Exception {
  InvalidDiscriminatorException(this.message);

  final String message;

  @override
  String toString() => 'InvalidDiscriminatorException: $message';
}
