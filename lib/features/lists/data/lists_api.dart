import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_headers.dart';
import '../../../core/network/api_response_parser.dart';
import '../../search/data/series.dart';
import 'list_membership.dart';
import 'list_movie.dart';
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

/// A list's series and movies come back from the same GET /lists/{id} call
/// (see Api\Controller\Lists\Show's own docblock) - each paginated
/// independently, so this carries both pages' worth of state at once.
class ListDetailPage {
  const ListDetailPage({
    required this.series,
    required this.seriesHasMore,
    required this.movies,
    required this.moviesHasMore,
  });

  final List<Series> series;
  final bool seriesHasMore;
  final List<ListMovie> movies;
  final bool moviesHasMore;
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

  Future<ListDetailPage> getListDetail(
    int listId, {
    int page = 0,
    int moviePage = 0,
    required String token,
  }) async {
    final data = await _get(
      '/api/lists/$listId?page=$page&movie_page=$moviePage',
      token: token,
    );
    final seriesResults = data['series'] as List<dynamic>? ?? [];
    final movieResults = data['movies'] as List<dynamic>? ?? [];
    return ListDetailPage(
      series: seriesResults
          .map((item) => Series.fromListRow(item as Map<String, dynamic>))
          .toList(),
      seriesHasMore: data['hasMore'] as bool? ?? false,
      movies: movieResults
          .map((item) => ListMovie.fromListRow(item as Map<String, dynamic>))
          .toList(),
      moviesHasMore: data['moviesHasMore'] as bool? ?? false,
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

  Future<void> addMovie(int listId, String tvdbId, {required String token}) {
    return _post('/api/lists/$listId/movies/$tvdbId', null, token: token);
  }

  Future<void> removeMovie(
    int listId,
    String tvdbId, {
    required String token,
  }) {
    return _delete('/api/lists/$listId/movies/$tvdbId', token: token);
  }

  /// Same neighbor-based reordering as reorderSerie, within this list's own
  /// movies (a separate ordering from its series - see UserListMovie's own
  /// docblock).
  Future<void> reorderMovie(
    int listId,
    String tvdbId, {
    String? afterTvdbId,
    required String token,
  }) {
    return _post(
      '/api/lists/$listId/movies/$tvdbId/reorder',
      {'after': afterTvdbId ?? ''},
      token: token,
    );
  }

  Future<List<ListMembership>> getMembership(
    String tvdbId, {
    required String token,
  }) async {
    final data = await _get('/api/lists/membership/$tvdbId', token: token);
    final results = data['lists'] as List<dynamic>? ?? [];
    return results
        .map((item) => ListMembership.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ListMembership>> getMembershipMovie(
    String tvdbId, {
    required String token,
  }) async {
    final data = await _get(
      '/api/lists/membership/movie/$tvdbId',
      token: token,
    );
    final results = data['lists'] as List<dynamic>? ?? [];
    return results
        .map((item) => ListMembership.fromJson(item as Map<String, dynamic>))
        .toList();
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
