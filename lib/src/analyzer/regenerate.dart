import 'dart:convert';

import 'package:http/http.dart' as http;

/// Forces a full regeneration of all macros for the given `clientId` and `contextPath`.
///
/// * if [filterOnlyDirectory] is true, it only include the files inside specified [contextPath].
/// * if [addToContext] is true and provided [contextPath] is not in the analysis context, it added
Future<void> forceRegenerateFor({
  required int clientId,
  required String contextPath,
  bool filterOnlyDirectory = false,
  bool addToContext = false,
  bool removeInContext = true,
}) async {
  final http.Response response;
  try {
    response = await http.post(
      Uri.parse('http://localhost:3232/force_regenerate'),
      body: jsonEncode({
        'clientId': clientId,
        'context': contextPath,
        'filterOnlyDirectory': filterOnlyDirectory,
        'addToContext': addToContext,
        'removeInContext': removeInContext,
      }),
    );
  } catch (e) {
    throw Exception('Unexpected error: $e');
  }

  if (response.statusCode != 200) {
    throw Exception('Unexpected status code: ${response.statusCode}, body: ${response.body}');
  }
}
