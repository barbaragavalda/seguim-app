import 'dart:convert';

Map<String, dynamic> decodeApiResponse(String body) {
  // The dev backend prepends PHP debug/warning noise before the JSON
  // payload (a known missing appacman_app_config table, or a deprecation
  // notice from a curl call) — never valid JSON from position 0. The last
  // `{` isn't reliable either once a response nests objects/arrays (e.g.
  // search results with their own remote_ids/translations), since that's
  // the start of some inner object, not the real payload. Instead, try
  // each `{` in order and keep the first one whose *entire* remaining
  // string parses as one JSON value — an inner object's substring always
  // leaves trailing characters behind (`]}],"error":false}` etc.), so it
  // fails this check, while the true payload start is the only position
  // where the whole rest of the body is exactly one JSON value.
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
