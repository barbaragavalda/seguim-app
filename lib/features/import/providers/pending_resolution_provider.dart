import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../movie_detail/data/movie_detail_api.dart';
import '../../search/data/search_result.dart';
import '../../series_detail/data/series_detail_api.dart';
import '../data/pending_entry.dart';
import '../data/pending_movies_api.dart';
import '../data/pending_series_api.dart';

class PendingResolutionState {
  const PendingResolutionState({
    this.isLoading = true,
    this.items = const [],
    this.resolvedCount = 0,
    this.busyKeys = const {},
    this.errorKey,
    this.actionErrorKey,
  });

  final bool isLoading;
  final List<PendingEntry> items;
  // how many have been resolved/skipped this session - used for the X/total
  // progress bar, same shape as rewatch's own Resolve screen
  final int resolvedCount;
  final Set<String> busyKeys;
  final String? errorKey;
  // set when a single resolve()/skip() action fails (e.g. a candidate
  // TheTVDB has since merged away) rather than the whole list load - kept
  // separate from errorKey above, which replaces the entire list with a
  // full-screen error message and would otherwise wipe out every other
  // still-pending item just because one action failed. The screen consumes
  // this via a SnackBar and clears it right after (see
  // PendingResolutionScreen's own ref.listen)
  final String? actionErrorKey;

  int get total => items.length + resolvedCount;

  PendingResolutionState copyWith({
    bool? isLoading,
    List<PendingEntry>? items,
    int? resolvedCount,
    Set<String>? busyKeys,
    String? errorKey,
    bool clearError = false,
    String? actionErrorKey,
    bool clearActionError = false,
  }) {
    return PendingResolutionState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      resolvedCount: resolvedCount ?? this.resolvedCount,
      busyKeys: busyKeys ?? this.busyKeys,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      actionErrorKey: clearActionError
          ? null
          : (actionErrorKey ?? this.actionErrorKey),
    );
  }
}

/// Merges Api\Model\SeriesImportPending and Api\Model\MovieImportPending
/// into one list for the app's single resolution screen - the user asked
/// for series to get the exact same pending-resolution treatment movies
/// already had, in the same place, rather than two separate screens.
class PendingResolutionController extends Notifier<PendingResolutionState> {
  late final PendingMoviesApi _movieApi;
  late final PendingSeriesApi _seriesApi;
  late final MovieDetailApi _movieDetailApi;
  late final SeriesDetailApi _seriesDetailApi;

  @override
  PendingResolutionState build() {
    _movieApi = PendingMoviesApi();
    _seriesApi = PendingSeriesApi();
    _movieDetailApi = MovieDetailApi();
    _seriesDetailApi = SeriesDetailApi();
    return const PendingResolutionState();
  }

  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final series = await _seriesApi.list(token: token);
      final movies = await _movieApi.list(token: token);
      final items = [
        ...series.map(PendingEntry.series),
        ...movies.map(PendingEntry.movie),
      ];
      state = PendingResolutionState(isLoading: false, items: items);
    } on PendingSeriesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } on PendingMoviesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  /// [tvdbIds] can have more than one entry for a movie - see
  /// PendingMoviesApi.resolve()'s own docblock on why (e.g. "Mulan" 1998 and
  /// 2020, both watched). A series never genuinely needs more than one, but
  /// the request shape stays the same either way.
  Future<void> resolve(PendingEntry entry, List<int> tvdbIds) async {
    final token = ref.read(authProvider).token;
    if (token == null || state.busyKeys.contains(entry.key) || tvdbIds.isEmpty) {
      return;
    }
    state = state.copyWith(
      busyKeys: {...state.busyKeys, entry.key},
      clearActionError: true,
    );
    try {
      if (entry.kind == PendingEntryKind.series) {
        await _seriesApi.resolve(entry.series!.id, tvdbIds, token: token);
      } else {
        await _movieApi.resolve(entry.movie!.id, tvdbIds, token: token);
      }
      _removeResolved(entry.key);
    } catch (e) {
      state = state.copyWith(
        busyKeys: {...state.busyKeys}..remove(entry.key),
        actionErrorKey: _actionErrorKeyFor(e),
      );
    }
  }

  /// Backs "Cerca manualment" - unlike resolve() above, [result] can be
  /// *either* kind, regardless of [entry]'s own: TV Time's own "shows" vs
  /// "movies" split doesn't always match TheTVDB's (e.g. a TV movie TV Time
  /// tracked as a one-episode "show" only exists on TheTVDB as a movie),
  /// so the search behind this action deliberately isn't restricted to
  /// [entry]'s kind - see SearchScreen.resolveEntry's own docblock.
  ///
  /// When [result]'s kind matches, this is exactly resolve() above (full
  /// watchlist/watched/rewatch snapshot replayed via the matching
  /// SeriesImportPending/MovieImportPending resolve() endpoint). When it
  /// doesn't, that snapshot has no compatible shape on the other side (a
  /// season/episode watched map doesn't mean anything for a movie, and
  /// vice versa) - so this instead just adds [result] straight to the
  /// right watchlist and drops the original pending row, same as picking
  /// "cap dels candidats" would have, rather than forcing it through a
  /// resolve endpoint that would silently fail (Series::sync() on a
  /// movie's own tvdb_id, or Movie::sync() on a series', never resolves to
  /// anything real - the two live in entirely separate id spaces).
  Future<void> resolveWithResult(PendingEntry entry, SearchResult result) async {
    final matchesKind = (entry.kind == PendingEntryKind.series) ==
        (result.type == SearchResultType.series);
    if (matchesKind) {
      await resolve(entry, [int.parse(result.tvdbId)]);
      return;
    }

    final token = ref.read(authProvider).token;
    if (token == null || state.busyKeys.contains(entry.key)) return;
    state = state.copyWith(
      busyKeys: {...state.busyKeys, entry.key},
      clearActionError: true,
    );
    try {
      if (result.type == SearchResultType.movie) {
        await _movieDetailApi.addToWatchlist(result.tvdbId, token: token);
      } else {
        await _seriesDetailApi.addToWatchlist(result.tvdbId, token: token);
      }
      if (entry.kind == PendingEntryKind.series) {
        await _seriesApi.skip(entry.series!.id, token: token);
      } else {
        await _movieApi.skip(entry.movie!.id, token: token);
      }
      _removeResolved(entry.key);
    } catch (e) {
      state = state.copyWith(
        busyKeys: {...state.busyKeys}..remove(entry.key),
        actionErrorKey: _actionErrorKeyFor(e),
      );
    }
  }

  Future<void> skip(PendingEntry entry) async {
    final token = ref.read(authProvider).token;
    if (token == null || state.busyKeys.contains(entry.key)) return;
    state = state.copyWith(
      busyKeys: {...state.busyKeys, entry.key},
      clearActionError: true,
    );
    try {
      if (entry.kind == PendingEntryKind.series) {
        await _seriesApi.skip(entry.series!.id, token: token);
      } else {
        await _movieApi.skip(entry.movie!.id, token: token);
      }
      _removeResolved(entry.key);
    } catch (e) {
      state = state.copyWith(
        busyKeys: {...state.busyKeys}..remove(entry.key),
        actionErrorKey: _actionErrorKeyFor(e),
      );
    }
  }

  void clearActionError() {
    if (state.actionErrorKey == null) return;
    state = state.copyWith(clearActionError: true);
  }

  void _removeResolved(String key) {
    state = state.copyWith(
      items: state.items.where((item) => item.key != key).toList(),
      resolvedCount: state.resolvedCount + 1,
      busyKeys: {...state.busyKeys}..remove(key),
    );
  }

  // PendingSeriesException/PendingMoviesException carry the backend's own
  // error string (e.g. "candidate_unavailable", or "404" for a pending row
  // that's already gone) - anything else (a network failure, a decode
  // error) falls back to the same generic key load() itself uses
  String _actionErrorKeyFor(Object error) {
    if (error is PendingSeriesException) return error.message;
    if (error is PendingMoviesException) return error.message;
    return 'unknown_error';
  }
}

final pendingResolutionProvider =
    NotifierProvider<PendingResolutionController, PendingResolutionState>(
      PendingResolutionController.new,
    );
