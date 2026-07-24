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
    this.selectedSeason,
    this.watchlistPending = false,
    this.errorKey,
  });

  final bool isLoading;
  final SeriesDetail? series;
  final List<Episode> episodes;
  final bool inWatchlist;
  final int? selectedSeason;
  final bool watchlistPending;
  final String? errorKey;

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

  SeriesDetailState copyWith({
    bool? isLoading,
    SeriesDetail? series,
    List<Episode>? episodes,
    bool? inWatchlist,
    int? selectedSeason,
    bool? watchlistPending,
    String? errorKey,
    bool clearError = false,
  }) {
    return SeriesDetailState(
      isLoading: isLoading ?? this.isLoading,
      series: series ?? this.series,
      episodes: episodes ?? this.episodes,
      inWatchlist: inWatchlist ?? this.inWatchlist,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      watchlistPending: watchlistPending ?? this.watchlistPending,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
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
      state = SeriesDetailState(
        isLoading: false,
        series: result.series,
        episodes: result.episodes,
        inWatchlist: result.inWatchlist,
        selectedSeason: seasons.isEmpty ? null : seasons.first,
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

  Future<void> toggleWatchlist() async {
    final tvdbId = _tvdbId;
    final token = ref.read(authProvider).token;
    if (tvdbId == null || token == null || state.watchlistPending) return;
    final wasInWatchlist = state.inWatchlist;
    state = state.copyWith(
      inWatchlist: !wasInWatchlist,
      watchlistPending: true,
    );
    try {
      if (wasInWatchlist) {
        await _api.removeFromWatchlist(tvdbId, token: token);
      } else {
        await _api.addToWatchlist(tvdbId, token: token);
      }
      state = state.copyWith(watchlistPending: false);
    } catch (_) {
      state = state.copyWith(
        inWatchlist: wasInWatchlist,
        watchlistPending: false,
      );
    }
  }

  Future<void> toggleEpisodeWatched(Episode episode) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final wasWatched = episode.watched;
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (e.tvdbId == episode.tvdbId)
            e.copyWith(watched: !wasWatched)
          else
            e,
      ],
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
              e.copyWith(watched: wasWatched)
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
    state = state.copyWith(
      episodes: [
        for (final e in state.episodes)
          if (idsToMark.contains(e.tvdbId)) e.copyWith(watched: true) else e,
      ],
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
              e.copyWith(watched: false)
            else
              e,
        ],
      );
    }
  }
}

final seriesDetailProvider =
    NotifierProvider<SeriesDetailController, SeriesDetailState>(
      SeriesDetailController.new,
    );
