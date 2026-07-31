import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../lists/data/list_movie.dart';
import '../data/movies_api.dart';

class MoviesState {
  const MoviesState({
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

  MoviesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<ListMovie>? items,
    bool? hasMore,
    int? page,
    String? errorKey,
    bool clearError = false,
  }) {
    return MoviesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Backs the bottom-tab "Pel·lícules" screen - only movies not yet watched
/// (`status: notWatched`), most-recently-added first. The searchable,
/// filterable "Les meves pel·lícules" profile screen (which does show
/// watched ones too, filterable) is a separate provider (myMoviesProvider)
/// - same split as WatchlistController vs MySeriesController for series.
class MoviesController extends Notifier<MoviesState> {
  late final MoviesApi _api;

  @override
  MoviesState build() {
    _api = MoviesApi();
    return const MoviesState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.list(status: MovieStatus.notWatched, token: token);
      state = MoviesState(
        isLoading: false,
        items: result.items,
        hasMore: result.hasMore,
      );
    } on MoviesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    final token = ref.read(authProvider).token;
    if (token == null || state.isLoadingMore || state.isLoading || !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.page + 1;
      final result = await _api.list(
        status: MovieStatus.notWatched,
        page: nextPage,
        token: token,
      );
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        page: nextPage,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final moviesProvider = NotifierProvider<MoviesController, MoviesState>(
  MoviesController.new,
);
