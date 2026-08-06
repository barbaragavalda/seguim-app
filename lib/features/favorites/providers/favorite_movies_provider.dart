import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../lists/data/list_movie.dart';
import '../data/favorites_api.dart';
import 'favorites_summary_provider.dart';

class FavoriteMoviesState {
  const FavoriteMoviesState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<ListMovie> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  FavoriteMoviesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<ListMovie>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return FavoriteMoviesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class FavoriteMoviesController extends Notifier<FavoriteMoviesState> {
  late final FavoritesApi _api;

  @override
  FavoriteMoviesState build() {
    _api = FavoritesApi();
    return const FavoriteMoviesState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.listMovies(token: token);
      state = FavoriteMoviesState(
        isLoading: false,
        items: result.items,
        hasMore: result.hasMore,
      );
    } on FavoritesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _api.listMovies(page: nextPage, token: token);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.hasMore,
        page: nextPage,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Optimistic - same "remove locally, roll back on failure" pattern as
  /// ListsController.deleteList()
  Future<void> remove(String tvdbId) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((m) => m.tvdbId != tvdbId).toList(),
    );
    try {
      await _api.removeMovie(tvdbId, token: token);
      // see FavoriteSeriesController.remove()'s own comment, identical
      // reasoning
      ref.read(favoritesSummaryProvider.notifier).load();
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }
}

final favoriteMoviesProvider =
    NotifierProvider<FavoriteMoviesController, FavoriteMoviesState>(
      FavoriteMoviesController.new,
    );
