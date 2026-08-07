import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/providers/favorites_summary_provider.dart';
import '../data/series_detail.dart';
import '../data/series_detail_api.dart';

class SeriesDetailState {
  const SeriesDetailState({
    this.isLoading = true,
    this.series,
    this.episodes = const [],
    this.inWatchlist = false,
    this.archived = false,
    this.removed = false,
    this.isFavorite = false,
    this.selectedSeason,
    this.watchlistPending = false,
    this.archivePending = false,
    this.removedPending = false,
    this.removeFromWatchlistPending = false,
    this.favoritePending = false,
    this.errorKey,
    this.actionErrorKey,
  });

  final bool isLoading;
  final SeriesDetail? series;
  final List<Episode> episodes;
  final bool inWatchlist;
  final bool archived;
  final bool removed;
  // independent of inWatchlist - see SeriesDetailResult.isFavorite's own
  // comment
  final bool isFavorite;
  final int? selectedSeason;
  final bool watchlistPending;
  final bool archivePending;
  final bool removedPending;
  final bool removeFromWatchlistPending;
  final bool favoritePending;
  final String? errorKey;
  // single-action failure (e.g. removeFromWatchlist's has_watch_history
  // rejection), separate from errorKey; consumed via SnackBar and cleared
  final String? actionErrorKey;

  /// Season 0 ("Especials") sorted after every real season, not first.
  List<int> get seasonNumbers {
    final numbers = episodes.map((e) => e.seasonNumber).toSet().toList()
      ..sort(_bySeasonWithSpecialsLast);
    return numbers;
  }

  List<Episode> get episodesForSelectedSeason {
    if (selectedSeason == null) return const [];
    final filtered =
        episodes.where((e) => e.seasonNumber == selectedSeason).toList()
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return filtered;
  }

  /// The backend rejects a hard delete once anything's been watched.
  bool get hasAnyWatchedEpisode => episodes.any((e) => e.watched);

  /// Null when there are no aired regular (season > 0) episodes to show
  /// progress for.
  double? get watchProgress {
    final counted = episodes.where((e) {
      if (e.seasonNumber <= 0) return false;
      final aired = e.aired == null ? null : DateTime.tryParse(e.aired!);
      return aired != null && !aired.isAfter(DateTime.now());
    });
    final total = counted.length;
    if (total == 0) return null;
    final watched = counted.where((e) => e.watched).length;
    return (watched / total).clamp(0.0, 1.0);
  }

  SeriesDetailState copyWith({
    bool? isLoading,
    SeriesDetail? series,
    List<Episode>? episodes,
    bool? inWatchlist,
    bool? archived,
    bool? removed,
    bool? isFavorite,
    int? selectedSeason,
    bool? watchlistPending,
    bool? archivePending,
    bool? removedPending,
    bool? removeFromWatchlistPending,
    bool? favoritePending,
    String? errorKey,
    bool clearError = false,
    String? actionErrorKey,
    bool clearActionError = false,
  }) {
    return SeriesDetailState(
      isLoading: isLoading ?? this.isLoading,
      series: series ?? this.series,
      episodes: episodes ?? this.episodes,
      inWatchlist: inWatchlist ?? this.inWatchlist,
      archived: archived ?? this.archived,
      removed: removed ?? this.removed,
      isFavorite: isFavorite ?? this.isFavorite,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      watchlistPending: watchlistPending ?? this.watchlistPending,
      archivePending: archivePending ?? this.archivePending,
      removedPending: removedPending ?? this.removedPending,
      removeFromWatchlistPending:
          removeFromWatchlistPending ?? this.removeFromWatchlistPending,
      favoritePending: favoritePending ?? this.favoritePending,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      actionErrorKey: clearActionError
          ? null
          : (actionErrorKey ?? this.actionErrorKey),
    );
  }
}

/// Sorts season numbers ascending, except 0 ("Especials") always goes last
/// rather than where it'd numerically fall first.
int _bySeasonWithSpecialsLast(int a, int b) {
  if (a == 0) return b == 0 ? 0 : 1;
  if (b == 0) return -1;
  return a.compareTo(b);
}

/// Which season the detail screen lands on by default: the season of the
/// furthest-watched episode, not the first season with any gap (an old
/// skipped/unrecovered episode shouldn't pull the default back there). Moves
/// to the next season once the furthest-watched one is done (an unaired
/// episode doesn't block "done"). Falls back to the first season with
/// anything left to watch if nothing's been watched yet.
int? _defaultSeasonFor(List<int> seasons, List<Episode> episodes) {
  if (seasons.isEmpty) return null;
  final now = DateTime.now();
  bool aired(Episode e) {
    final date = e.aired == null ? null : DateTime.tryParse(e.aired!);
    return date != null && !date.isAfter(now);
  }

  Episode? lastWatched;
  for (final e in episodes) {
    if (e.seasonNumber <= 0 || !e.watched) continue;
    final current = lastWatched;
    final isFurther =
        current == null ||
        e.seasonNumber > current.seasonNumber ||
        (e.seasonNumber == current.seasonNumber &&
            e.episodeNumber > current.episodeNumber);
    if (isFurther) lastWatched = e;
  }

  if (lastWatched == null) {
    for (final season in seasons) {
      final hasUnwatchedAired = episodes
          .where((e) => e.seasonNumber == season)
          .any((e) => !e.watched && aired(e));
      if (hasUnwatchedAired) return season;
    }
    return seasons.first;
  }

  final season = lastWatched.seasonNumber;
  final seasonDone = episodes
      .where((e) => e.seasonNumber == season)
      .every((e) => e.watched || !aired(e));
  if (!seasonDone) return season;

  final index = seasons.indexOf(season);
  return index != -1 && index + 1 < seasons.length ? seasons[index + 1] : season;
}

class SeriesDetailController extends Notifier<SeriesDetailState> {
  late final SeriesDetailApi _api;
  String? _tvdbId;

  @override
  SeriesDetailState build() {
    _api = SeriesDetailApi();
    return const SeriesDetailState();
  }

  Future<void> load(String tvdbId) async {
    _tvdbId = tvdbId;
    final token = ref.read(authProvider).token ?? ApiConfig.defaultToken;
    state = const SeriesDetailState(isLoading: true);
    try {
      final result = await _api.getDetail(tvdbId, token: token);
      if (_tvdbId != tvdbId) return;
      // season 0 excluded - unlike seasonNumbers, it should never be the default
      final seasons =
          result.episodes
              .map((e) => e.seasonNumber)
              .where((n) => n > 0)
              .toSet()
              .toList()
            ..sort();
      final defaultSeason = _defaultSeasonFor(seasons, result.episodes);
      state = SeriesDetailState(
        isLoading: false,
        series: result.series,
        episodes: result.episodes,
        inWatchlist: result.inWatchlist,
        archived: result.archived,
        removed: result.removed,
        isFavorite: result.isFavorite,
        selectedSeason: defaultSeason,
      );
    } on SeriesDetailException catch (e) {
      if (_tvdbId != tvdbId) return;
      state = SeriesDetailState(isLoading: false, errorKey: e.message);
    } catch (_) {
      if (_tvdbId != tvdbId) return;
      state = const SeriesDetailState(
        isLoading: false,
        errorKey: 'unknown_error',
      );
    }
  }

  void selectSeason(int season) {
    state = state.copyWith(selectedSeason: season);
  }

  /// Once added, stays added; setArchived()/setRemoved() are the reversible
  /// ways to hide it without losing watch history.
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

  Future<void> setArchived(bool archived) async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.archivePending) return;
    final previous = state.archived;
    state = state.copyWith(archived: archived, archivePending: true);
    try {
      await _api.setArchived(tvdbId, archived, token: token);
      state = state.copyWith(archivePending: false);
    } catch (_) {
      state = state.copyWith(archived: previous, archivePending: false);
    }
  }

  Future<void> setRemoved(bool removed) async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.removedPending) return;
    final previous = state.removed;
    state = state.copyWith(removed: removed, removedPending: true);
    try {
      await _api.setRemoved(tvdbId, removed, token: token);
      state = state.copyWith(removedPending: false);
    } catch (_) {
      state = state.copyWith(removed: previous, removedPending: false);
    }
  }

  /// Independent of the watchlist toggles above - see SeriesDetailResult.
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
      // ProfileScreen's preview row won't catch up unless we reload it
      ref.read(favoritesSummaryProvider.notifier).load();
    } catch (_) {
      state = state.copyWith(isFavorite: previous, favoritePending: false);
    }
  }

  /// Hard delete. The backend also enforces hasAnyWatchedEpisode, so a
  /// stale/racy state surfaces as actionErrorKey instead of losing history.
  Future<void> removeFromWatchlist() async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.removeFromWatchlistPending) {
      return;
    }
    state = state.copyWith(
      removeFromWatchlistPending: true,
      clearActionError: true,
    );
    try {
      await _api.removeFromWatchlist(tvdbId, token: token);
      state = state.copyWith(
        inWatchlist: false,
        archived: false,
        removed: false,
        removeFromWatchlistPending: false,
      );
    } on SeriesDetailException catch (e) {
      state = state.copyWith(
        removeFromWatchlistPending: false,
        actionErrorKey: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        removeFromWatchlistPending: false,
        actionErrorKey: 'unknown_error',
      );
    }
  }

  void clearActionError() {
    state = state.copyWith(clearActionError: true);
  }

  /// Toggles between watchCount 0 and 1; rewatchEpisode is the only way to
  /// reach watchCount > 1.
  Future<void> toggleEpisodeWatched(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final wasWatched = episode.watched;
    final previousCount = episode.watchCount;
    // marking watched implies following the series and clears `archived`
    // ("veure més tard" is the opposite of actually watching); mirrored here
    // so the toggle updates immediately instead of waiting for a reload
    final wasInWatchlist = state.inWatchlist;
    final wasArchived = state.archived;
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (e.tvdbId == episode.tvdbId)
            e.copyWith(watched: !wasWatched, watchCount: wasWatched ? 0 : 1)
          else
            e,
      ],
      inWatchlist: wasWatched ? wasInWatchlist : true,
      archived: wasWatched ? null : false,
    );
    try {
      if (wasWatched) {
        await _api.markEpisodeUnwatched(episode.tvdbId, token: token);
      } else {
        await _api.markEpisodeWatched(episode.tvdbId, token: token);
      }
    } catch (_) {
      state = state.copyWith(
        episodes: [
          for (final e in state.episodes)
            if (e.tvdbId == episode.tvdbId)
              e.copyWith(watched: wasWatched, watchCount: previousCount)
            else
              e,
        ],
        inWatchlist: wasInWatchlist,
        archived: wasWatched ? null : wasArchived,
      );
    }
  }

  /// Records another watch event; [episode.watched] is already true, so
  /// only watchCount changes.
  Future<void> rewatchEpisode(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final previousCount = episode.watchCount;
    // same "clears archived" reasoning as toggleEpisodeWatched() - a
    // rewatch is just as much watching something from the series
    final wasArchived = state.archived;
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (e.tvdbId == episode.tvdbId)
            e.copyWith(watchCount: previousCount + 1)
          else
            e,
      ],
      archived: false,
    );
    try {
      await _api.rewatchEpisode(episode.tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(
        episodes: [
          for (final e in state.episodes)
            if (e.tvdbId == episode.tvdbId)
              e.copyWith(watchCount: previousCount)
            else
              e,
        ],
        archived: wasArchived,
      );
    }
  }

  /// Inverse of rewatchEpisode: collapses watchCount back to 1.
  Future<void> undoRewatch(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final previousCount = episode.watchCount;
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (e.tvdbId == episode.tvdbId) e.copyWith(watchCount: 1) else e,
      ],
    );
    try {
      await _api.undoRewatch(episode.tvdbId, token: token);
    } catch (_) {
      state = state.copyWith(
        episodes: [
          for (final e in state.episodes)
            if (e.tvdbId == episode.tvdbId)
              e.copyWith(watchCount: previousCount)
            else
              e,
        ],
      );
    }
  }

  /// Episodes earlier in [episode]'s season, still unwatched - used to ask
  /// the user whether to mark those too before marking [episode] itself.
  List<Episode> unwatchedBefore(Episode episode) {
    return state.episodesForSelectedSeason
        .where((e) => e.episodeNumber < episode.episodeNumber && !e.watched)
        .toList();
  }

  Future<void> markWatchedThrough(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final toMark = state.episodesForSelectedSeason
        .where((e) => e.episodeNumber <= episode.episodeNumber && !e.watched)
        .toList();
    if (toMark.isEmpty) return;
    final idsToMark = toMark.map((e) => e.tvdbId).toSet();
    final wasInWatchlist = state.inWatchlist;
    // same "clears archived" reasoning as toggleEpisodeWatched()
    final wasArchived = state.archived;
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (idsToMark.contains(e.tvdbId))
            e.copyWith(watched: true, watchCount: 1)
          else
            e,
      ],
      inWatchlist: true,
      archived: false,
    );
    try {
      await Future.wait(
        toMark.map((e) => _api.markEpisodeWatched(e.tvdbId, token: token)),
      );
    } catch (_) {
      state = state.copyWith(
        episodes: [
          for (final e in state.episodes)
            if (idsToMark.contains(e.tvdbId))
              e.copyWith(watched: false, watchCount: 0)
            else
              e,
        ],
        inWatchlist: wasInWatchlist,
        archived: wasArchived,
      );
    }
  }
}

final seriesDetailProvider =
    NotifierProvider<SeriesDetailController, SeriesDetailState>(
      SeriesDetailController.new,
    );
