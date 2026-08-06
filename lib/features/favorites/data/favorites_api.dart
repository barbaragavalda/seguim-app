import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../lists/data/list_movie.dart';
import '../../lists/data/user_list.dart' show ListPreviewItem;
import '../../search/data/series.dart';

class FavoritesException implements Exception {
  const FavoritesException(this.message);

  final String message;
}

class FavoriteSeriesResult {
  const FavoriteSeriesResult({required this.items, required this.hasMore});

  final List<Series> items;
  final bool hasMore;
}

class FavoriteMoviesResult {
  const FavoriteMoviesResult({required this.items, required this.hasMore});

  final List<ListMovie> items;
  final bool hasMore;
}

class FavoritesSummary {
  const FavoritesSummary({
    required this.seriesCount,
    required this.seriesPreview,
    required this.moviesCount,
    required this.moviesPreview,
  });

  final int seriesCount;
  final List<ListPreviewItem> seriesPreview;
  final int moviesCount;
  final List<ListPreviewItem> moviesPreview;

  static const empty = FavoritesSummary(
    seriesCount: 0,
    seriesPreview: [],
    moviesCount: 0,
    moviesPreview: [],
  );
}

class FavoritesApi {
  FavoritesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FavoriteSeriesResult> listSeries({
    int page = 0,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/series?page=$page'),
      headers: apiHeaders(token),
    );
    final data = _decode(response);
    final items = (data['series'] as List<dynamic>? ?? [])
        .map((item) => Series.fromListRow(item as Map<String, dynamic>))
        .toList();
    return FavoriteSeriesResult(
      items: items,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<FavoriteMoviesResult> listMovies({
    int page = 0,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/movies?page=$page'),
      headers: apiHeaders(token),
    );
    final data = _decode(response);
    final items = (data['movies'] as List<dynamic>? ?? [])
        .map((item) => ListMovie.fromListRow(item as Map<String, dynamic>))
        .toList();
    return FavoriteMoviesResult(
      items: items,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  /// Used by SearchScreen's own favorites-picker mode (see FavoriteSeriesScreen/
  /// FavoriteMoviesScreen's "+" button) - the detail screens' own heart
  /// toggle goes through SeriesDetailApi/MovieDetailApi instead, same
  /// endpoint either way
  Future<void> addSerie(String tvdbId, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/series/$tvdbId'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Future<void> addMovie(String tvdbId, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/movies/$tvdbId'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Future<void> removeSerie(String tvdbId, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/series/$tvdbId'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  Future<void> removeMovie(String tvdbId, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/movies/$tvdbId'),
      headers: apiHeaders(token),
    );
    _decode(response);
  }

  /// Backs the two "Sèries favorites"/"Pel·lícules favorites" preview rows
  /// pinned above ProfileScreen's own list-preview rows.
  Future<FavoritesSummary> summary({required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/favorites/summary'),
      headers: apiHeaders(token),
    );
    final data = _decode(response);
    return FavoritesSummary(
      seriesCount: (data['series_count'] as num?)?.toInt() ?? 0,
      seriesPreview: (data['series_preview'] as List<dynamic>? ?? [])
          .map((item) => ListPreviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      moviesCount: (data['movies_count'] as num?)?.toInt() ?? 0,
      moviesPreview: (data['movies_preview'] as List<dynamic>? ?? [])
          .map((item) => ListPreviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
    } on FormatException {
      throw const FavoritesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw FavoritesException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
