import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import 'series_detail.dart';

class SeriesDetailException implements Exception {
  const SeriesDetailException(this.message);

  final String message;
}

class SeriesDetailResult {
  const SeriesDetailResult({
    required this.series,
    required this.episodes,
    required this.inWatchlist,
    required this.archived,
    required this.removed,
  });

  final SeriesDetail series;
  final List<Episode> episodes;
  final bool inWatchlist;
  final bool archived;
  final bool removed;
}

class SeriesDetailApi {
  SeriesDetailApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SeriesDetailResult> getDetail(
    String tvdbId, {
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/series/$tvdbId'),
      headers: apiHeaders(token),
    );
    final data = _decode(response.body);
    final seriesJson = data['series'] as Map<String, dynamic>? ?? {};
    final episodesJson = data['episodes'] as List<dynamic>? ?? [];
    return SeriesDetailResult(
      series: SeriesDetail.fromJson(seriesJson),
      episodes: episodesJson
          .map((item) => Episode.fromJson(item as Map<String, dynamic>))
          .toList(),
      inWatchlist: data['in_watchlist'] as bool? ?? false,
      archived: data['archived'] as bool? ?? false,
      removed: data['removed'] as bool? ?? false,
    );
  }

  Future<void> addToWatchlist(String tvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId'),
      headers: apiHeaders(token),
    );
  }

  Future<void> setArchived(
    String tvdbId,
    bool archived, {
    required String token,
  }) {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId/archived');
    return archived
        ? _client.post(uri, headers: apiHeaders(token))
        : _client.delete(uri, headers: apiHeaders(token));
  }

  Future<void> setRemoved(
    String tvdbId,
    bool removed, {
    required String token,
  }) {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId/removed');
    return removed
        ? _client.post(uri, headers: apiHeaders(token))
        : _client.delete(uri, headers: apiHeaders(token));
  }

  /// Hard delete - unlike setArchived/setRemoved (reversible flags on the
  /// same row), this drops the row entirely. The backend rejects it
  /// (`has_watch_history`) once anything from the series has ever been
  /// watched - see Api\Controller\Watchlist\Remove's own docblock - which
  /// the UI itself already prevents reaching by only offering this action
  /// when there's nothing watched to lose.
  Future<void> removeFromWatchlist(String tvdbId, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId'),
      headers: apiHeaders(token),
    );
    _decode(response.body);
  }

  Future<void> markEpisodeWatched(
    String episodeTvdbId, {
    required String token,
  }) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/watched'),
      headers: apiHeaders(token),
    );
  }

  /// A full reset - every watch event for this episode is removed, not
  /// just the most recent rewatch (see rewatchEpisode below).
  Future<void> markEpisodeUnwatched(
    String episodeTvdbId, {
    required String token,
  }) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/watched'),
      headers: apiHeaders(token),
    );
  }

  /// Unlike markEpisodeWatched (a no-op if already watched), always
  /// records a new watch event.
  Future<void> rewatchEpisode(String episodeTvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/rewatch'),
      headers: apiHeaders(token),
    );
  }

  /// The inverse of rewatchEpisode - collapses back down to a single watch
  /// rather than fully unwatching it (unlike markEpisodeUnwatched).
  Future<void> undoRewatch(String episodeTvdbId, {required String token}) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/rewatch'),
      headers: apiHeaders(token),
    );
  }

  Map<String, dynamic> _decode(String body) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(body);
    } on FormatException {
      throw const SeriesDetailException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw SeriesDetailException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
