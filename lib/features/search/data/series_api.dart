import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_response_parser.dart';
import 'series.dart';

class SeriesSearchException implements Exception {
  const SeriesSearchException(this.message);

  final String message;
}

class SeriesSearchResult {
  const SeriesSearchResult({required this.items, required this.hasMore});

  final List<Series> items;
  final bool hasMore;
}

class SeriesApi {
  SeriesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SeriesSearchResult> search(String query, {int page = 0}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/series/search').replace(
        queryParameters: {'query': query, 'page': '$page'},
      ),
      headers: {'Authorization': ApiConfig.defaultToken},
    );
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response.body);
    } on FormatException {
      throw const SeriesSearchException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw SeriesSearchException(error is String ? error : 'unknown_error');
    }
    final results = data['results'] as List<dynamic>? ?? [];
    return SeriesSearchResult(
      items: results
          .map((item) => Series.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
