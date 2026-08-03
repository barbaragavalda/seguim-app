import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../lists/data/list_movie.dart';

class MoviesException implements Exception {
  const MoviesException(this.message);

  final String message;
}

/// The 3 statuses `GET /api/movies/watchlist?status=` partitions every
/// movie into - see Api\Model\MovieWatchlist::listByStatus()'s docblock on
/// the backend. Simpler than SeriesStatus: a movie has no episodes, so
/// there's no "watching" partial state - just watched or not.
enum MovieStatus { all, notWatched, watched }

extension MovieStatusApiValue on MovieStatus {
  String get apiValue => switch (this) {
    MovieStatus.all => 'all',
    MovieStatus.notWatched => 'not_watched',
    MovieStatus.watched => 'watched',
  };
}

class MoviesPage {
  const MoviesPage({required this.items, required this.hasMore});

  final List<ListMovie> items;
  final bool hasMore;
}

/// Parses into [ListMovie] (poster, not fanart) - the "Pel·lícules" tab
/// shows a poster grid, same shape MyMoviesApi already parses this same
/// endpoint into (see that class' own docblock on why it isn't shared as
/// one class, mirroring the series-side WatchlistApi/MySeriesApi split).
class MoviesApi {
  MoviesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<MoviesPage> list({
    required MovieStatus status,
    String? search,
    int page = 0,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/movies/watchlist').replace(
        queryParameters: {
          'status': status.apiValue,
          'page': '$page',
          if (search != null && search.isNotEmpty) 'search': search,
        },
      ),
      headers: apiHeaders(token),
    );
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response);
    } on FormatException {
      throw const MoviesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw MoviesException(error is String ? error : 'unknown_error');
    }
    final results = data['watchlist'] as List<dynamic>? ?? [];
    return MoviesPage(
      items: results
          .map((item) => ListMovie.fromListRow(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
