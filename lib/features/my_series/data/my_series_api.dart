import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../search/data/series.dart';

class MySeriesException implements Exception {
  const MySeriesException(this.message);

  final String message;
}

/// The 6 statuses `GET /api/watchlist?status=` partitions every series
/// into - see Api\Model\Watchlist::listByStatus()'s docblock on the
/// backend for how they're computed. `all` is unfiltered - every other
/// status is a subset of it.
enum SeriesStatus { all, watching, notStarted, finished, archived, removed }

extension SeriesStatusApiValue on SeriesStatus {
  String get apiValue => switch (this) {
    SeriesStatus.all => 'all',
    SeriesStatus.watching => 'watching',
    SeriesStatus.notStarted => 'not_started',
    SeriesStatus.finished => 'finished',
    SeriesStatus.archived => 'archived',
    SeriesStatus.removed => 'removed',
  };
}

class MySeriesPage {
  const MySeriesPage({required this.items, required this.hasMore});

  final List<Series> items;
  final bool hasMore;
}

class MySeriesApi {
  MySeriesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<MySeriesPage> list({
    required SeriesStatus status,
    String? search,
    int page = 0,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/watchlist').replace(
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
      throw const MySeriesException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw MySeriesException(error is String ? error : 'unknown_error');
    }
    final results = data['watchlist'] as List<dynamic>? ?? [];
    return MySeriesPage(
      items: results
          .map((item) => Series.fromListRow(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
