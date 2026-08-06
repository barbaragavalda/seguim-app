import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../search/data/series.dart';
import '../data/favorites_api.dart';
import 'favorites_summary_provider.dart';

class FavoriteSeriesState {
  const FavoriteSeriesState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.items = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorKey,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<Series> items;
  final bool hasMore;
  final int page;
  final String? errorKey;

  FavoriteSeriesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Series>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return FavoriteSeriesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class FavoriteSeriesController extends Notifier<FavoriteSeriesState> {
  late final FavoritesApi _api;

  @override
  FavoriteSeriesState build() {
    _api = FavoritesApi();
    return const FavoriteSeriesState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.listSeries(token: token);
      state = FavoriteSeriesState(
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
      final result = await _api.listSeries(page: nextPage, token: token);
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
      items: state.items.where((s) => s.tvdbId != tvdbId).toList(),
    );
    try {
      await _api.removeSerie(tvdbId, token: token);
      // ProfileScreen's own preview row otherwise only catches up once
      // something else happens to reload it (selecting the Perfil tab
      // again) - popping straight back here from a push never does, same
      // staleness pendingCountProvider used to hit. A fresh load() rather
      // than a local decrement since the preview itself (not just the
      // count) needs the real next-in-line poster, not just one fewer slot
      ref.read(favoritesSummaryProvider.notifier).load();
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }
}

final favoriteSeriesProvider =
    NotifierProvider<FavoriteSeriesController, FavoriteSeriesState>(
      FavoriteSeriesController.new,
    );
