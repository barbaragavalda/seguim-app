import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../search/data/series.dart';
import 'user_list.dart';

class ListsException implements Exception {
  const ListsException(this.message);

  final String message;
}

class ListsPage {
  const ListsPage({required this.items, required this.hasMore});

  final List<UserList> items;
  final bool hasMore;
}

class ListSeriesPage {
  const ListSeriesPage({required this.items, required this.hasMore});

  final List<Series> items;
  final bool hasMore;
}

class ListsApi {
  ListsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ListsPage> getLists({int page = 0, required String token}) async {
    final data = await _get('/api/lists?page=$page', token: token);
    final results = data['lists'] as List<dynamic>? ?? [];
    return ListsPage(
      items: results
          .map((item) => UserList.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<int> createList(String name, {required String token}) async {
    final data = await _post('/api/lists', {'name': name}, token: token);
    return (data['id'] as num).toInt();
  }

  Future<String> renameList(
    int id,
    String name, {
    required String token,
  }) async {
    final data = await _post('/api/lists/$id', {'name': name}, token: token);
    return data['name'] as String;
  }

  Future<void> deleteList(int id, {required String token}) {
    return _delete('/api/lists/$id', token: token);
  }

  /// Moves this list right after [afterId] among the user's own lists, or
  /// to the very front if null - see UserList::moveAfter()'s own docblock
  /// (backend) for why it's neighbor-based rather than a full reorder.
  Future<void> reorderList(int id, {int? afterId, required String token}) {
    return _post(
      '/api/lists/$id/reorder',
      {'after': afterId?.toString() ?? ''},
      token: token,
    );
  }

  Future<ListSeriesPage> getListSeries(
    int listId, {
    int page = 0,
    required String token,
  }) async {
    final data = await _get('/api/lists/$listId?page=$page', token: token);
    final results = data['series'] as List<dynamic>? ?? [];
    return ListSeriesPage(
      items: results
          .map(
            (item) => Series.fromListRow(item as Map<String, dynamic>),
          )
          .toList(),
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<void> addSerie(int listId, String tvdbId, {required String token}) {
    return _post('/api/lists/$listId/series/$tvdbId', null, token: token);
  }

  Future<void> removeSerie(
    int listId,
    String tvdbId, {
    required String token,
  }) {
    return _delete('/api/lists/$listId/series/$tvdbId', token: token);
  }

  /// Same neighbor-based reordering as reorderList above, within this one
  /// list - [afterTvdbId] null moves [tvdbId] to the very front.
  Future<void> reorderSerie(
    int listId,
    String tvdbId, {
    String? afterTvdbId,
    required String token,
  }) {
    return _post(
      '/api/lists/$listId/series/$tvdbId/reorder',
      {'after': afterTvdbId ?? ''},
      token: token,
    );
  }

  Future<Map<String, dynamic>> _get(String path, {required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: apiHeaders(token),
    );
    return _decode(response.body);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String>? body, {
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: apiHeaders(token),
      body: body,
    );
    return _decode(response.body);
  }

  Future<void> _delete(String path, {required String token}) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: apiHeaders(token),
    );
    _decode(response.body);
  }

  Map<String, dynamic> _decode(String body) {
    late final Map<String, dynamic> data;
    try {
      data = decodeApiResponse(body);
    } on FormatException {
      throw const ListsException('unknown_error');
    }
    final error = data['error'];
    if (error != false) {
      throw ListsException(error is String ? error : 'unknown_error');
    }
    return data;
  }
}
