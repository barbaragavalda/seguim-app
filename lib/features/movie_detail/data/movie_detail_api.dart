import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import 'movie_detail.dart';

class MovieDetailException implements Exception {
  const MovieDetailException(this.message);

  final String message;
}

class MovieDetailResult {
  const MovieDetailResult({
    required this.movie,
    required this.inWatchlist,
    required this.watched,
    required this.watchCount,
  });

  final MovieDetail movie;
  final bool inWatchlist;
  final bool watched;
  final int watchCount;
}

class MovieDetailApi {
  MovieDetailApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<MovieDetailResult> getDetail(
    String tvdbId, {
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId'),
      headers: apiHeaders(token),
    );
    final data = _decode(response.body);
    final movieJson = data['movie'] as Map<String, dynamic>? ?? {};
    return MovieDetailResult(
      movie: MovieDetail.fromJson(movieJson),
      inWatchlist: data['in_watchlist'] as bool? ?? false,
      watched: data['watched'] as bool? ?? false,
      watchCount: (data['watch_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> addToWatchlist(String tvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watchlist'),
      headers: apiHeaders(token),
    );
  }

  Future<void> markWatched(String tvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watched'),
      headers: apiHeaders(token),
    );
  }

  /// A full reset - every watch event for this movie is removed, not just
  /// the most recent rewatch (see rewatch below).
  Future<void> markUnwatched(String tvdbId, {required String token}) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watched'),
      headers: apiHeaders(token),
    );
  }

  /// Unlike markWatched (a no-op if already watched), always records a new
  /// watch event.
  Future<void> rewatch(String tvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/rewatch'),
      headers: apiHeaders(token),
    );
  }

  /// The inverse of rewatch - collapses back down to a single watch rather
  /// than fully unwatching it (unlike markUnwatched).
  Future<void> undoRewatch(String tvdbId, {required String token}) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/rewatch'),
      headers: apiHeaders(token),
    );
  }

  Map<String, dynamic> _decode(String body) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(body);
    } on FormatException {
      throw const MovieDetailException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw MovieDetailException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
