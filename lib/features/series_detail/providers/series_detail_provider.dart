import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
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
    this.selectedSeason,
    this.watchlistPending = false,
    this.archivePending = false,
    this.removedPending = false,
    this.removeFromWatchlistPending = false,
    this.errorKey,
    this.actionErrorKey,
  });

  final bool isLoading;
  final SeriesDetail? series;
  final List<Episode> episodes;
  final bool inWatchlist;
  final bool archived;
  final bool removed;
  final int? selectedSeason;
  final bool watchlistPending;
  final bool archivePending;
  final bool removedPending;
  final bool removeFromWatchlistPending;
  final String? errorKey;
  // set when removeFromWatchlist() fails (e.g. the backend's own
  // has_watch_history rejection - see that controller's own docblock)
  // rather than the whole detail failing to load - kept separate from
  // errorKey above, which replaces the entire screen with a full-screen
  // error message. The screen consumes this via a SnackBar and clears it
  // right after, same pattern as PendingResolutionState.actionErrorKey
  final String? actionErrorKey;

  List<int> get seasonNumbers {
    final numbers =
        episodes.map((e) => e.seasonNumber).where((n) => n > 0).toSet().toList()
          ..sort();
    return numbers;
  }

  List<Episode> get episodesForSelectedSeason {
    if (selectedSeason == null) return const [];
    final filtered =
        episodes.where((e) => e.seasonNumber == selectedSeason).toList()
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return filtered;
  }

  /// Whether removeFromWatchlist() below is even offered - the backend
  /// rejects a hard delete once anything's been watched (see that
  /// controller's own docblock on why), so there's no point showing the
  /// action at all once that's true.
  bool get hasAnyWatchedEpisode => episodes.any((e) => e.watched);

  /// null when there's nothing to show a progress bar for (no aired
  /// regular episodes at all) - same "season > 0, already aired" counting
  /// as the backend's own watchProgressForSeries() (Api\Model\Episode),
  /// computed here instead since the full episode list is already loaded.
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
    int? selectedSeason,
    bool? watchlistPending,
    bool? archivePending,
    bool? removedPending,
    bool? removeFromWatchlistPending,
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
      selectedSeason: selectedSeason ?? this.selectedSeason,
      watchlistPending: watchlistPending ?? this.watchlistPending,
      archivePending: archivePending ?? this.archivePending,
      removedPending: removedPending ?? this.removedPending,
      removeFromWatchlistPending:
          removeFromWatchlistPending ?? this.removeFromWatchlistPending,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      actionErrorKey: clearActionError
          ? null
          : (actionErrorKey ?? this.actionErrorKey),
    );
  }
}

/// Which season the detail screen lands on by default - the first one still
/// "in progress" (has at least one already-aired episode still unwatched),
/// so finishing a season moves the default on to the next one instead of
/// getting stuck on the last one with any watched episode at all (the old
/// rule - e.g. finishing House of the Dragon's season 2 kept defaulting
/// back to season 2 instead of showing season 3). An unaired episode never
/// counts against a season here either way, so a season nothing has aired
/// for yet is trivially "in progress" too - which is exactly what's wanted
/// once every earlier season really is finished, with nothing left to fall
/// through to instead. Falls back to the last season once every season is
/// done this way (fully caught up, or genuinely finished the whole series).
int? _defaultSeasonFor(List<int> seasons, List<Episode> episodes) {
  if (seasons.isEmpty) return null;
  final now = DateTime.now();
  bool seasonDone(int season) {
    return episodes.where((e) => e.seasonNumber == season).every((e) {
      final aired = e.aired == null ? null : DateTime.tryParse(e.aired!);
      return e.watched || aired == null || aired.isAfter(now);
    });
  }

  for (final season in seasons) {
    if (!seasonDone(season)) return season;
  }
  return seasons.last;
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

  /// Adds the series to the watchlist - once there, it stays there;
  /// see setArchived()/setRemoved() for the two reversible ways to hide it
  /// again without losing watched-episode history (the plain "remove
  /// entirely" action deliberately isn't exposed here, only from
  /// MySeriesScreen - see the profile "Sèries" section's own reasoning).
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

  /// Hard delete - only offered by the UI when hasAnyWatchedEpisode is
  /// false, but the backend enforces that too (has_watch_history), so a
  /// stale/race-y state still surfaces as an actionErrorKey instead of
  /// silently losing watch history.
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

  /// Toggles between fully unwatched (watchCount 0) and watched-once
  /// (watchCount 1) - only reachable for a currently-unwatched episode, or
  /// as the "delete" choice from the already-watched dialog (see
  /// _handleWatchedEpisodeTap), which resets watchCount to 0 same as the
  /// backend's full-reset DELETE. rewatchEpisode below is the only way to
  /// reach watchCount > 1.
  Future<void> toggleEpisodeWatched(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final wasWatched = episode.watched;
    final previousCount = episode.watchCount;
    // marking an episode watched implies following the series - see
    // Api\Controller\Episode\Watch's matching backend-side add(). Marking
    // one watched also clears `archived` there ("veure més tard" is the
    // opposite of actually watching something from the series) - mirrored
    // here so the toggle button updates immediately instead of waiting for
    // a reload; unwatching (wasWatched true) doesn't touch it either way.
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

  /// Records another watch event - [episode.watched] is already true (this
  /// is only reachable from the "already watched, what do you want to do"
  /// dialog, see series_detail_screen.dart), so only watchCount changes.
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

  /// The inverse of rewatchEpisode - collapses watchCount back down to 1
  /// (still watched, just not "rewatched" anymore). Only reachable from
  /// the already-watched dialog when watchCount > 1.
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
