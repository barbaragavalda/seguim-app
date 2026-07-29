import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../movies/data/movie_watchlist_item.dart';
import '../../movies/data/movies_api.dart';

class MyMoviesState {
  const MyMoviesState({
    this.status = MovieStatus.all,
    this.search = '',
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final MovieStatus status;
  final String search;
  final bool isLoading;
  final bool isLoadingMore;
  final List<MovieWatchlistItem> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  MyMoviesState copyWith({
    MovieStatus? status,
    String? search,
    bool? isLoading,
    bool? isLoadingMore,
    List<MovieWatchlistItem>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return MyMoviesState(
      status: status ?? this.status,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Backs the profile's "Les meves pel·lícules" searchable/filterable
/// browsing screen - counterpart of MySeriesController for movies.
class MyMoviesController extends Notifier<MyMoviesState> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final MoviesApi _api;
  Timer? _debounce;
  int _requestId = 0;

  @override
  MyMoviesState build() {
    _api = MoviesApi();
    ref.onDispose(() => _debounce?.cancel());
    return const MyMoviesState();
  }

  Future<void> load() async {
    _debounce?.cancel();
    final requestId = ++_requestId;
    final token = ref.read(authProvider).token;
    if (token == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.list(
        status: state.status,
        search: state.search.trim(),
        token: token,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        isLoading: false,
        items: result.items,
        hasMore: result.hasMore,
        page: 0,
      );
    } on MoviesException catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (requestId != _requestId) return;
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  void setStatus(MovieStatus status) {
    if (status == state.status) return;
    _debounce?.cancel();
    state = state.copyWith(status: status);
    load();
  }

  void onSearchChanged(String search) {
    _debounce?.cancel();
    state = state.copyWith(search: search);
    _debounce = Timer(_debounceDuration, load);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    final requestId = _requestId;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.list(
        status: state.status,
        search: state.search.trim(),
        page: nextPage,
        token: ref.read(authProvider).token!,
      );
      if (requestId != _requestId) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
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

final myMoviesProvider = NotifierProvider<MyMoviesController, MyMoviesState>(
  MyMoviesController.new,
);
