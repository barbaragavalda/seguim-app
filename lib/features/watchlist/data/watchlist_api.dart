import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_response_parser.dart';
import 'watchlist_item.dart';

class WatchlistException implements Exception {
  const WatchlistException(this.message);

  final String message;
}

class NotStartedPage {
  const NotStartedPage({required this.items, required this.hasMore});

  final List<WatchlistItem> items;
  final bool hasMore;
}

class WatchlistApi {
  WatchlistApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WatchlistItem>> getWatching({required String token}) async {
    final data = await _get('/api/watchlist/watching', token: token);
    final results = data['watchlist'] as List<dynamic>? ?? [];
    return results
        .map((item) => WatchlistItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<NotStartedPage> getNotStarted({
    required String token,
    int page = 0,
  }) async {
    final data = await _get(
      '/api/watchlist/not-started?page=$page',
      token: token,
    );
    final results = data['watchlist'] as List<dynamic>? ?? [];
    return NotStartedPage(
      items: results
          .map((item) => WatchlistItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {'Authorization': token},
    );
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(response.body);
    } on FormatException {
      throw const WatchlistException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw WatchlistException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
