class Utils {
  static String escapeQuote(String input) {
    return input.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  static bool isValueTypeCanBeOfType(String valueType, String ofType) {
    if (valueType == ofType) {
      return true;
    }

    return switch (ofType) {
      'Object' || 'Object?' || 'dynamic' => true,
      _ when '$valueType?' == ofType => true, // non nullable can be used for nullable type
      _ => valueType == 'dynamic',
    };
  }
}
