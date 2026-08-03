import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import 'pending_movie.dart';

class PendingMoviesException implements Exception {
  const PendingMoviesException(this.message);

  final String message;
}

class PendingMoviesApi {
  PendingMoviesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PendingMovie>> list({required String token}) async {
    final data = await _get('/api/import/movies/pending', token: token);
    final results = data['pending'] as List<dynamic>? ?? [];
    return results
        .map((item) => PendingMovie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// [watchedTvdbIds]/[pendingTvdbIds] together can have more than one
  /// entry - TV Time's own single entry sometimes represents more than one
  /// real movie it couldn't tell apart (e.g. "Mulan" 1998 and 2020) - a
  /// candidate goes in whichever list matches what the user actually knows
  /// happened to it (watched, vs. just added to the watchlist) - see the
  /// backend's own Api\Model\MovieImportPending::resolve() docblock
  Future<void> resolve(
    int id, {
    List<int> watchedTvdbIds = const [],
    List<int> pendingTvdbIds = const [],
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/import/movies/pending/$id/resolve'),
      headers: {
        ...apiHeaders(token),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: [
        ...watchedTvdbIds.map((id) => 'watched_tvdb_ids[]=$id'),
        ...pendingTvdbIds.map((id) => 'pending_tvdb_ids[]=$id'),
      ].join('&'),
    );
    _decode(response);
  }

  Future<void> skip(int id, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/import/movies/pending/$id'),
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
      throw const PendingMoviesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw PendingMoviesException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
