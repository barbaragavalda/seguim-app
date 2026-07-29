import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../search/data/series.dart';
import '../data/list_movie.dart';
import '../data/lists_api.dart';

class ListDetailState {
  const ListDetailState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isLoadingMoreMovies = false,
    this.name = '',
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.movieItems = const [],
    this.movieHasMore = false,
    this.moviePage = 0,
    this.errorKey,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final bool isLoadingMoreMovies;
  final String name;
  final List<Series> items;
  final bool hasMore;
  final int page;
  final List<ListMovie> movieItems;
  final bool movieHasMore;
  final int moviePage;
  final String? errorKey;

  ListDetailState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isLoadingMoreMovies,
    String? name,
    List<Series>? items,
    bool? hasMore,
    int? page,
    List<ListMovie>? movieItems,
    bool? movieHasMore,
    int? moviePage,
    String? errorKey,
    bool clearError = false,
  }) {
    return ListDetailState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingMoreMovies: isLoadingMoreMovies ?? this.isLoadingMoreMovies,
      name: name ?? this.name,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      movieItems: movieItems ?? this.movieItems,
      movieHasMore: movieHasMore ?? this.movieHasMore,
      moviePage: moviePage ?? this.moviePage,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Same "no FamilyNotifier in Riverpod 3.3.2" shape as SeriesDetailController/
/// MySeriesController - a plain Notifier with an explicit load(id) rather
/// than a family provider. Series and movies are fetched together (one
/// GET /lists/{id} call - see Api\Controller\Lists\Show's own docblock) but
/// paginated/reordered fully independently of each other from here on,
/// mirroring the backend's own separate user_list_serie/user_list_movie
/// tables.
class ListDetailController extends Notifier<ListDetailState> {
  late final ListsApi _api;
  int? _listId;

  @override
  ListDetailState build() {
    _api = ListsApi();
    return const ListDetailState();
  }

  Future<void> load(int listId, String name) async {
    _listId = listId;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = ListDetailState(isLoading: true, name: name);
    try {
      final result = await _api.getListDetail(listId, token: token);
      if (_listId != listId) return;
      state = ListDetailState(
        isLoading: false,
        name: name,
        items: _dedupe(result.series),
        hasMore: result.seriesHasMore,
        movieItems: _dedupeMovies(result.movies),
        movieHasMore: result.moviesHasMore,
      );
    } on ListsException catch (e) {
      if (_listId != listId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (_listId != listId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    final listId = _listId;
    if (listId == null || state.isLoadingMore || state.isLoading || !state.hasMore) {
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.getListDetail(
        listId,
        page: nextPage,
        moviePage: state.moviePage,
        token: token,
      );
      if (_listId != listId) return;
      state = state.copyWith(
        // a series added optimistically (addSerie) since the last load
        // lands at the end on both sides (local: appended; server: highest
        // ordering) - if that push landed it inside this next page's
        // range, the fetch would otherwise return it a second time
        items: _dedupe([...state.items, ...result.series]),
        isLoadingMore: false,
        hasMore: result.seriesHasMore,
        page: nextPage,
      );
    } catch (_) {
      if (_listId != listId) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> loadMoreMovies() async {
    final listId = _listId;
    if (listId == null ||
        state.isLoadingMoreMovies ||
        state.isLoading ||
        !state.movieHasMore) {
      return;
    }
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final nextMoviePage = state.moviePage + 1;
    state = state.copyWith(isLoadingMoreMovies: true);
    try {
      final result = await _api.getListDetail(
        listId,
        page: state.page,
        moviePage: nextMoviePage,
        token: token,
      );
      if (_listId != listId) return;
      state = state.copyWith(
        movieItems: _dedupeMovies([...state.movieItems, ...result.movies]),
        isLoadingMoreMovies: false,
        movieHasMore: result.moviesHasMore,
        moviePage: nextMoviePage,
      );
    } catch (_) {
      if (_listId != listId) return;
      state = state.copyWith(isLoadingMoreMovies: false);
    }
  }

  /// Returns null on success, or an error message to show inline. Renaming
  /// from here (rather than the lists tab) doesn't update ListsController's
  /// own copy - see AppShell's Llistes-tab-switch reload, same pattern as
  /// WatchlistScreen's watchlist-tab-switch refresh.
  Future<String?> renameList(String name) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return 'unknown_error';
    try {
      final saved = await _api.renameList(listId, name, token: token);
      state = state.copyWith(name: saved);
      return null;
    } on ListsException catch (e) {
      return e.message;
    } catch (_) {
      return 'unknown_error';
    }
  }

  Future<void> addSerie(Series series) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    if (state.items.any((s) => s.tvdbId == series.tvdbId)) return;
    state = state.copyWith(items: [...state.items, series]);
    try {
      await _api.addSerie(listId, series.tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(
        items: state.items.where((s) => s.tvdbId != series.tvdbId).toList(),
      );
    }
  }

  Future<void> removeSerie(String tvdbId) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((s) => s.tvdbId != tvdbId).toList(),
    );
    try {
      await _api.removeSerie(listId, tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  Future<void> reorderSerie(String tvdbId, {String? afterTvdbId}) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.items;
    state = state.copyWith(items: _moved(state.items, tvdbId, afterTvdbId));
    try {
      await _api.reorderSerie(
        listId,
        tvdbId,
        afterTvdbId: afterTvdbId,
        token: token,
      );
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  Future<void> addMovie(ListMovie movie) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    if (state.movieItems.any((m) => m.tvdbId == movie.tvdbId)) return;
    state = state.copyWith(movieItems: [...state.movieItems, movie]);
    try {
      await _api.addMovie(listId, movie.tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(
        movieItems: state.movieItems
            .where((m) => m.tvdbId != movie.tvdbId)
            .toList(),
      );
    }
  }

  Future<void> removeMovie(String tvdbId) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.movieItems;
    state = state.copyWith(
      movieItems: state.movieItems.where((m) => m.tvdbId != tvdbId).toList(),
    );
    try {
      await _api.removeMovie(listId, tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(movieItems: previous);
    }
  }

  Future<void> reorderMovie(String tvdbId, {String? afterTvdbId}) async {
    final listId = _listId;
    final token = ref.read(authProvider).token;
    if (listId == null || token == null) return;
    final previous = state.movieItems;
    state = state.copyWith(
      movieItems: _movedMovies(state.movieItems, tvdbId, afterTvdbId),
    );
    try {
      await _api.reorderMovie(
        listId,
        tvdbId,
        afterTvdbId: afterTvdbId,
        token: token,
      );
    } catch (_) {
      state = state.copyWith(movieItems: previous);
    }
  }

  /// Keeps the first occurrence of each tvdbId - see loadMore()'s own
  /// comment for why a series can otherwise appear twice.
  List<Series> _dedupe(List<Series> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.tvdbId)) item,
    ];
  }

  List<ListMovie> _dedupeMovies(List<ListMovie> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.tvdbId)) item,
    ];
  }

  List<Series> _moved(List<Series> items, String tvdbId, String? afterTvdbId) {
    final result = [...items];
    final moving = result.firstWhere((s) => s.tvdbId == tvdbId);
    result.remove(moving);
    if (afterTvdbId == null) {
      result.insert(0, moving);
    } else {
      final index = result.indexWhere((s) => s.tvdbId == afterTvdbId);
      result.insert(index == -1 ? result.length : index + 1, moving);
    }
    return result;
  }

  List<ListMovie> _movedMovies(
    List<ListMovie> items,
    String tvdbId,
    String? afterTvdbId,
  ) {
    final result = [...items];
    final moving = result.firstWhere((m) => m.tvdbId == tvdbId);
    result.remove(moving);
    if (afterTvdbId == null) {
      result.insert(0, moving);
    } else {
      final index = result.indexWhere((m) => m.tvdbId == afterTvdbId);
      result.insert(index == -1 ? result.length : index + 1, moving);
    }
    return result;
  }
}

final listDetailProvider =
    NotifierProvider<ListDetailController, ListDetailState>(
      ListDetailController.new,
    );
