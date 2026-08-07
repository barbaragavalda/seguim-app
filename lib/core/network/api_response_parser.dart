import 'dart:convert';

import 'package:http/http.dart' as http;

/// Set once at startup (see main.dart) to authProvider's logOut(), so a
/// stale token (HTTP 401) gets cleared as soon as any API call notices it.
void Function()? onAuthExpired;

Map<String, dynamic> decodeApiResponse(http.Response response) {
  if (response.statusCode == 401) {
    onAuthExpired?.call();
  }
  final body = response.body;
  // dev backend prepends PHP debug noise before the JSON payload, so
  // position 0 isn't reliable; try each `{` and keep the first whose entire
  // remaining string parses as one JSON value (an inner object's substring
  // always leaves trailing characters behind)
  for (var i = body.indexOf('{'); i != -1; i = body.indexOf('{', i + 1)) {
    try {
      final decoded = jsonDecode(body.substring(i));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // not the real start (mid-noise or an inner object) — keep looking
    }
  }
  throw const FormatException('No JSON object found in response body');
}
