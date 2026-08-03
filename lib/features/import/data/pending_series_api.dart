import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import 'pending_series.dart';

class PendingSeriesException implements Exception {
  const PendingSeriesException(this.message);

  final String message;
}

/// Mirrors PendingMoviesApi - see its own docblock. The only real
/// difference is the resolve() request has no reason to ever carry more
/// than one tvdb_id in practice (a series doesn't have movies' "watched
/// under one ambiguous entry" scenario), but the backend still accepts an
/// array for consistency, so this keeps the same shape rather than special-
/// casing a single id.
class PendingSeriesApi {
  PendingSeriesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PendingSeries>> list({required String token}) async {
    final data = await _get('/api/import/series/pending', token: token);
    final results = data['pending'] as List<dynamic>? ?? [];
    return results
        .map((item) => PendingSeries.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolve(int id, List<int> tvdbIds, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/import/series/pending/$id/resolve'),
      headers: {
        ...apiHeaders(token),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: tvdbIds.map((tvdbId) => 'tvdb_ids[]=$tvdbId').join('&'),
    );
    _decode(response);
  }

  Future<void> skip(int id, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/import/series/pending/$id'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, {required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: apiHeaders(token),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
    } on FormatException {
      throw const PendingSeriesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw PendingSeriesException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
