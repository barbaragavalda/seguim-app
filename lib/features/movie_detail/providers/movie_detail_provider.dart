import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_summary_provider.dart';
import '../data/movie_detail.dart';
import '../data/movie_detail_api.dart';

class MovieDetailState {
  const MovieDetailState({
    this.isLoading = true,
    this.movie,
    this.inWatchlist = false,
    this.watched = false,
    this.watchCount = 0,
    this.watchlistPending = false,
    this.isFavorite = false,
    this.favoritePending = false,
    this.errorKey,
  });

  final bool isLoading;
  final MovieDetail? movie;
  final bool inWatchlist;
  final bool watched;
  final int watchCount;
  final bool watchlistPending;
  // independent of inWatchlist - see MovieDetailResult.isFavorite's own
  // comment
  final bool isFavorite;
  final bool favoritePending;
  final String? errorKey;

  MovieDetailState copyWith({
    bool? isLoading,
    MovieDetail? movie,
    bool? inWatchlist,
    bool? watched,
    int? watchCount,
    bool? watchlistPending,
    bool? isFavorite,
    bool? favoritePending,
    String? errorKey,
    bool clearError = false,
  }) {
    return MovieDetailState(
      isLoading: isLoading ?? this.isLoading,
      movie: movie ?? this.movie,
      inWatchlist: inWatchlist ?? this.inWatchlist,
      watched: watched ?? this.watched,
      watchCount: watchCount ?? this.watchCount,
      watchlistPending: watchlistPending ?? this.watchlistPending,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritePending: favoritePending ?? this.favoritePending,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

class MovieDetailController extends Notifier<MovieDetailState> {
  late final MovieDetailApi _api;
  String? _tvdbId;

  @override
  MovieDetailState build() {
    _api = MovieDetailApi();
    return const MovieDetailState();
  }

  Future<void> load(String tvdbId) async {
    _tvdbId = tvdbId;
    final token = ref.read(authProvider).token ?? ApiConfig.defaultToken;
    state = const MovieDetailState(isLoading: true);
    try {
      final result = await _api.getDetail(tvdbId, token: token);
      if (_tvdbId != tvdbId) return;
      state = MovieDetailState(
        isLoading: false,
        movie: result.movie,
        inWatchlist: result.inWatchlist,
        watched: result.watched,
        watchCount: result.watchCount,
        isFavorite: result.isFavorite,
      );
    } on MovieDetailException catch (e) {
      if (_tvdbId != tvdbId) return;
      state = MovieDetailState(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (_tvdbId != tvdbId) return;
      state = const MovieDetailState(isLoading: false, errorKey: 'unknown_error');
    }
  }

  /// Adds the movie to the watchlist - once there, it stays there, same as
  /// SeriesDetailController.addToWatchlist() (a movie has no archived/
  /// removed toggles to reverse it with, unlike a series).
  Future<void> addToWatchlist() async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.watchlistPending) return;
    state = state.copyWith(inWatchlist: true, watchlistPending: true);
    try {
      await _api.addToWatchlist(tvdbId, token: token);
      state = state.copyWith(watchlistPending: false);
    } catch (_) {
      state = state.copyWith(inWatchlist: false, watchlistPending: false);
    }
  }

  /// Toggles between fully unwatched (watchCount 0) and watched-once
  /// (watchCount 1) - only reachable for a currently-unwatched movie, or as
  /// the "delete" choice from the already-watched dialog (see
  /// movie_detail_screen.dart's _handleWatchedTap), which resets watchCount
  /// to 0. rewatch() below is the only way to reach watchCount > 1.
  Future<void> toggleWatched() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final tvdbId = _tvdbId;
    if (tvdbId == null) return;
    final wasWatched = state.watched;
    final previousCount = state.watchCount;
    final wasInWatchlist = state.inWatchlist;
    // marking a movie watched implies tracking it - see
    // Api\Controller\Movie\Watch's matching backend-side add()
    state = state.copyWith(
      watched: !wasWatched,
      watchCount: wasWatched ? 0 : 1,
      inWatchlist: wasWatched ? wasInWatchlist : true,
    );
    try {
      if (wasWatched) {
        await _api.markUnwatched(tvdbId, token: token);
      } else {
        await _api.markWatched(tvdbId, token: token);
      }
    } catch (_) {
      state = state.copyWith(
        watched: wasWatched,
        watchCount: previousCount,
        inWatchlist: wasInWatchlist,
      );
    }
  }

  /// Independent of the watchlist toggle above - see MovieDetailResult.
  /// isFavorite's own comment
  Future<void> setFavorite(bool favorite) async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.favoritePending) return;
    final previous = state.isFavorite;
    state = state.copyWith(isFavorite: favorite, favoritePending: true);
    try {
      await _api.setFavorite(tvdbId, favorite, token: token);
      state = state.copyWith(favoritePending: false);
      // see SeriesDetailController.setFavorite()'s own comment, identical
      // reasoning
      ref.read(favoritesSummaryProvider.notifier).load();
    } catch (_) {
      state = state.copyWith(isFavorite: previous, favoritePending: false);
    }
  }

  /// Records another watch event - [state.watched] is already true (only
  /// reachable from the "already watched" dialog), so only watchCount
  /// changes.
  Future<void> rewatch() async {
    final token = ref.read(authProvider).token;
    final tvdbId = _tvdbId;
    if (token == null || tvdbId == null) return;
    final previousCount = state.watchCount;
    state = state.copyWith(watchCount: previousCount + 1);
    try {
      await _api.rewatch(tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(watchCount: previousCount);
    }
  }

  /// The inverse of rewatch - collapses watchCount back down to 1 (still
  /// watched, just not "rewatched" anymore). Only reachable from the
  /// already-watched dialog when watchCount > 1.
  Future<void> undoRewatch() async {
    final token = ref.read(authProvider).token;
    final tvdbId = _tvdbId;
    if (token == null || tvdbId == null) return;
    final previousCount = state.watchCount;
    state = state.copyWith(watchCount: 1);
    try {
      await _api.undoRewatch(tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(watchCount: previousCount);
    }
  }
}

final movieDetailProvider =
    NotifierProvider<MovieDetailController, MovieDetailState>(
      MovieDetailController.new,
    );
