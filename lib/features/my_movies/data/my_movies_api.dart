import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../lists/data/list_movie.dart';
import '../../movies/data/movies_api.dart' show MovieStatus, MovieStatusApiValue;

class MyMoviesException implements Exception {
  const MyMoviesException(this.message);

  final String message;
}

class MyMoviesPage {
  const MyMoviesPage({required this.items, required this.hasMore});

  final List<ListMovie> items;
  final bool hasMore;
}

/// Same `GET /api/movies/watchlist?status=` endpoint as MoviesApi (the
/// bottom-tab screen), but parsed into [ListMovie] instead of
/// [MovieWatchlistItem] - this screen shows a poster grid (with a watched
/// badge via ListMovie.watchProgress), not a landscape row, so it needs
/// the poster (`image`) rather than the fanart. Kept as its own class
/// rather than adding a second parse path to MoviesApi, mirroring how
/// MySeriesApi is already its own class alongside WatchlistApi for the
/// exact same series-side split.
class MyMoviesApi {
  MyMoviesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<MyMoviesPage> list({
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
      throw const MyMoviesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw MyMoviesException(error is String ? error : 'unknown_error');
    }
    final results = data['watchlist'] as List<dynamic>? ?? [];
    return MyMoviesPage(
      items: results
          .map((item) => ListMovie.fromListRow(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
