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
    required this.isFavorite,
  });

  final MovieDetail movie;
  final bool inWatchlist;
  final bool watched;
  final int watchCount;
  // independent of inWatchlist - see Api\Controller\Favorites\AddMovie's
  // own docblock on why favoriting doesn't require tracking first
  final bool isFavorite;
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
    final data = _decode(response);
    final movieJson = data['movie'] as Map<String, dynamic>? ?? {};
    return MovieDetailResult(
      movie: MovieDetail.fromJson(movieJson),
      inWatchlist: data['in_watchlist'] as bool? ?? false,
      watched: data['watched'] as bool? ?? false,
      watchCount: (data['watch_count'] as num?)?.toInt() ?? 0,
      isFavorite: data['is_favorite'] as bool? ?? false,
    );
  }

  Future<void> setFavorite(
    String tvdbId,
    bool favorite, {
    required String token,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/favorites/movies/$tvdbId');
    final response = favorite
        ? await _client.post(uri, headers: apiHeaders(token))
        : await _client.delete(uri, headers: apiHeaders(token));
    _decode(response);
  }

  Future<void> addToWatchlist(String tvdbId, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watchlist'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Future<void> markWatched(String tvdbId, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watched'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  /// A full reset - every watch event for this movie is removed, not just
  /// the most recent rewatch (see rewatch below).
  Future<void> markUnwatched(String tvdbId, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/watched'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  /// Unlike markWatched (a no-op if already watched), always records a new
  /// watch event.
  Future<void> rewatch(String tvdbId, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/rewatch'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  /// The inverse of rewatch - collapses back down to a single watch rather
  /// than fully unwatching it (unlike markUnwatched).
  Future<void> undoRewatch(String tvdbId, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/$tvdbId/rewatch'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
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
