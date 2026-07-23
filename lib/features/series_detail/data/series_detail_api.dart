import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
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
  });

  final SeriesDetail series;
  final List<Episode> episodes;
  final bool inWatchlist;
}

class SeriesDetailApi {
  SeriesDetailApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SeriesDetailResult> getDetail(
    String tvdbId, {
    required String token,
    String? languageCode,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/series/$tvdbId'),
      headers: {
        'Authorization': token,
        if (languageCode != null) 'Accept-Language': languageCode,
      },
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
    );
  }

  Future<void> addToWatchlist(String tvdbId, {required String token}) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId'),
      headers: {'Authorization': token},
    );
  }

  Future<void> removeFromWatchlist(String tvdbId, {required String token}) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$tvdbId'),
      headers: {'Authorization': token},
    );
  }

  Future<void> markEpisodeWatched(
    String episodeTvdbId, {
    required String token,
  }) {
    return _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/watched'),
      headers: {'Authorization': token},
    );
  }

  Future<void> markEpisodeUnwatched(
    String episodeTvdbId, {
    required String token,
  }) {
    return _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/episode/$episodeTvdbId/watched'),
      headers: {'Authorization': token},
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
