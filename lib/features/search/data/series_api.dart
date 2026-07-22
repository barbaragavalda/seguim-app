import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_response_parser.dart';
import 'series.dart';

class SeriesSearchException implements Exception {
  const SeriesSearchException(this.message);

  final String message;
}

class SeriesApi {
  SeriesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Series>> search(String query) async {
    final response = await _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/series/search',
      ).replace(queryParameters: {'query': query}),
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
    return results
        .map((item) => Series.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
