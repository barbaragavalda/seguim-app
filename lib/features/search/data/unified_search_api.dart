import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import 'search_result.dart';

class UnifiedSearchException implements Exception {
  const UnifiedSearchException(this.message);

  final String message;
}

class UnifiedSearchResult {
  const UnifiedSearchResult({required this.items, required this.hasMore});

  final List<SearchResult> items;
  final bool hasMore;
}

/// Hits the unified `/api/search` endpoint (series+movies mixed) - used by
/// the bottom-tab Search screen. The "add to list" flow keeps using
/// SeriesApi.search() instead (series-only, since lists stay series-only).
class UnifiedSearchApi {
  UnifiedSearchApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// [token] is the logged-in user's own token, when there is one - lets
  /// the backend compute each series result's watch progress (Api\
  /// Controller\Search\Search::withWatchProgress()); omitted/null falls
  /// back to the app's shared token, same as before, and search still
  /// works fully logged-out, just without progress bars.
  Future<UnifiedSearchResult> search(
    String query, {
    int page = 0,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/search').replace(
        queryParameters: {'query': query, 'page': '$page'},
      ),
      headers: apiHeaders(token ?? ApiConfig.defaultToken),
    );
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response.body);
    } on FormatException {
      throw const UnifiedSearchException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw UnifiedSearchException(error is String ? error : 'unknown_error');
    }
    final results = data['results'] as List<dynamic>? ?? [];
    return UnifiedSearchResult(
      items: results
          .map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }
}
