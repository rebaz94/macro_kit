class Utils {
  static String escapeQuote(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  static bool isValueTypeCanBeOfType(
    String valueType,
    String expectedType, {
    required bool valueTypeIsGeneric,
  }) {
    if (valueTypeIsGeneric || valueType == expectedType) {
      return true;
    }

    return switch (expectedType) {
      'Object' || 'Object?' || 'dynamic' => true,
      _ when '$valueType?' == expectedType => true, // non nullable can be used for nullable type
      _ => valueType == 'dynamic',
    };
  }
}
