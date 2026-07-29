import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lists/data/list_movie.dart';
import '../data/search_result.dart';
import '../data/series.dart' as series_model;
import '../data/unified_search_api.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.results = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final String query;
  final bool isLoading;
  final bool isLoadingMore;
  final List<SearchResult> results;
  final bool hasMore;
  final int page;
  final String? errorKey;

  SearchState copyWith({
    String? query,
    bool? isLoading,
    bool? isLoadingMore,
    List<SearchResult>? results,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      results: results ?? this.results,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class SearchController extends Notifier<SearchState> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final UnifiedSearchApi _unifiedApi;
  Timer? _debounce;
  int _requestId = 0;

  @override
  SearchState build() {
    _unifiedApi = UnifiedSearchApi();
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    state = state.copyWith(
      query: query,
      clearError: true,
      isLoading: trimmed.isNotEmpty,
    );
    if (trimmed.isEmpty) {
      _requestId++;
      state = state.copyWith(
        results: const [],
        isLoading: false,
        hasMore: false,
        page: 0,
      );
      return;
    }
    _debounce = Timer(_debounceDuration, () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    try {
      final result = await _unifiedApi.search(query, page: 0);
      if (requestId != _requestId) return;
      state = state.copyWith(
        results: result.items,
        isLoading: false,
        hasMore: result.hasMore,
        page: 0,
      );
    } on UnifiedSearchException catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;
    final query = state.query.trim();
    if (query.isEmpty) return;

    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _unifiedApi.search(query, page: nextPage);
      if (requestId != _requestId) return;
      state = state.copyWith(
        results: [...state.results, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final searchProvider = NotifierProvider<SearchController, SearchState>(
  SearchController.new,
);

/// Converts a unified [SearchResult] into the series-only model the lists
/// feature expects (see search/data/series.dart) - only ever called for a
/// [SearchResult] with type == series.
series_model.Series seriesFromSearchResult(SearchResult result) {
  return series_model.Series(
    tvdbId: result.tvdbId,
    name: result.name,
    year: result.year,
    imageUrl: result.imageUrl,
    status: result.status,
  );
}

/// Same as seriesFromSearchResult above, for a [SearchResult] with
/// type == movie.
ListMovie movieFromSearchResult(SearchResult result) {
  return ListMovie(
    tvdbId: result.tvdbId,
    name: result.name,
    year: result.year,
    imageUrl: result.imageUrl,
    status: result.status,
  );
}
