import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../movie_detail/data/movie_detail_api.dart';
import '../../search/data/search_result.dart';
import '../../series_detail/data/series_detail_api.dart';
import '../data/pending_entry.dart';
import '../data/pending_movies_api.dart';
import '../data/pending_series_api.dart';
import 'pending_count_provider.dart';

class PendingResolutionState {
  const PendingResolutionState({
    this.isLoading = true,
    this.items = const [],
    this.resolvedCount = 0,
    this.busyKeys = const {},
    this.selected = const {},
    this.pendingSelected = const {},
    this.manualPicks = const {},
    this.isConfirmingAll = false,
    this.errorKey,
    this.actionErrorKey,
  });

  final bool isLoading;
  final List<PendingEntry> items;
  final int resolvedCount;
  final Set<String> busyKeys;
  // lives here, not widget State, so it survives navigating to "Cerca
  // manualment" and back, and confirmAll() can see every card's ticks at once
  final Map<String, Set<int>> selected;
  // subset of selected[entryKey] marked "pendent de veure" instead of "vist";
  // movies only, since a title with no release date can need multiple
  // candidates ticked (each with its own watched/pending call)
  final Map<String, Set<int>> pendingSelected;
  // a "Cerca manualment" pick, held until Confirma; mutually exclusive with
  // `selected` for the same key (toggleCandidate/setManualPick clear the other)
  final Map<String, SearchResult> manualPicks;
  // coarser than busyKeys (per-entry) - lets the global button spinner/disable
  final bool isConfirmingAll;
  final String? errorKey;
  // single-action failure, separate from errorKey (which blanks the whole
  // list); consumed via SnackBar and cleared right after
  final String? actionErrorKey;

  int get total => items.length + resolvedCount;

  int get selectedEntryCount =>
      selected.values.where((s) => s.isNotEmpty).length + manualPicks.length;

  int get pendingCandidateCount =>
      pendingSelected.values.fold(0, (sum, ids) => sum + ids.length);

  int get watchedCandidateCount =>
      selected.values.fold(0, (sum, ids) => sum + ids.length) +
      manualPicks.length -
      pendingCandidateCount;

  PendingResolutionState copyWith({
    bool? isLoading,
    List<PendingEntry>? items,
    int? resolvedCount,
    Set<String>? busyKeys,
    Map<String, Set<int>>? selected,
    Map<String, Set<int>>? pendingSelected,
    Map<String, SearchResult>? manualPicks,
    bool? isConfirmingAll,
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
      selected: selected ?? this.selected,
      pendingSelected: pendingSelected ?? this.pendingSelected,
      manualPicks: manualPicks ?? this.manualPicks,
      isConfirmingAll: isConfirmingAll ?? this.isConfirmingAll,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      actionErrorKey: clearActionError
          ? null
          : (actionErrorKey ?? this.actionErrorKey),
    );
  }
}

/// Merges Api\Model\SeriesImportPending and Api\Model\MovieImportPending
/// into one list for the app's single resolution screen.
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

  /// Safe to call again on an already-loaded screen: re-fetching keeps
  /// `selected`/`manualPicks`/`busyKeys`, filtered down to entries the fresh
  /// list still has, and leaves `resolvedCount` alone so the progress bar
  /// doesn't jump backwards on every poll.
  Future<void> load() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    final isFirstLoad = state.items.isEmpty && state.resolvedCount == 0;
    state = state.copyWith(isLoading: isFirstLoad, clearError: true);
    try {
      final series = await _seriesApi.list(token: token);
      final movies = await _movieApi.list(token: token);
      final items = [
        ...series.map(PendingEntry.series),
        ...movies.map(PendingEntry.movie),
      ];
      final validKeys = items.map((item) => item.key).toSet();
      final selected = Map<String, Set<int>>.fromEntries(
        state.selected.entries.where((e) => validKeys.contains(e.key)),
      );
      final pendingSelected = Map<String, Set<int>>.fromEntries(
        state.pendingSelected.entries.where(
          (e) => validKeys.contains(e.key),
        ),
      );
      state = state.copyWith(
        isLoading: false,
        items: items,
        selected: selected,
        pendingSelected: pendingSelected,
        manualPicks: Map.fromEntries(
          state.manualPicks.entries.where((e) => validKeys.contains(e.key)),
        ),
        busyKeys: state.busyKeys.where(validKeys.contains).toSet(),
      );
    } on PendingSeriesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } on PendingMoviesException catch (e) {
      state = state.copyWith(isLoading: false, errorKey: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorKey: 'unknown_error');
    }
  }

  /// [tvdbIds] can have more than one entry for a movie (e.g. "Mulan" 1998
  /// and 2020). [pendingTvdbIds], a subset of [tvdbIds], marks which should
  /// be added as "pendent de veure" instead of "vist" - only ever non-empty
  /// for a movie.
  Future<void> resolve(
    PendingEntry entry,
    List<int> tvdbIds, {
    Set<int> pendingTvdbIds = const {},
  }) async {
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
        final watched = tvdbIds.where((id) => !pendingTvdbIds.contains(id));
        await _movieApi.resolve(
          entry.movie!.id,
          watchedTvdbIds: watched.toList(),
          pendingTvdbIds: pendingTvdbIds.toList(),
          token: token,
        );
      }
      _removeResolved(entry.key);
    } catch (e) {
      state = state.copyWith(
        busyKeys: {...state.busyKeys}..remove(entry.key),
        actionErrorKey: _actionErrorKeyFor(e),
      );
    }
  }

  /// Backs "Cerca manualment" - [result] can be either kind regardless of
  /// [entry]'s own, since TV Time's shows/movies split doesn't always match
  /// TheTVDB's. When the kind matches, this is just resolve() above. When it
  /// doesn't, the watched/rewatch snapshot has no compatible shape on the
  /// other side, so instead [result] is added straight to the matching
  /// watchlist and the original pending row is dropped.
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

  /// Cycles one candidate for [entryKey] through unselected -> ticked ->
  /// (if [allowPending]) the other ticked state -> unselected. Series never
  /// gets a second ticked state (watch history is per-episode, not
  /// per-candidate). [defaultToPending] picks which ticked state the first
  /// tap lands on. Clears any manual pick for the same entry.
  void toggleCandidate(
    String entryKey,
    int tvdbId, {
    bool allowPending = false,
    bool defaultToPending = false,
  }) {
    final selected = {...(state.selected[entryKey] ?? const <int>{})};
    final pending = {...(state.pendingSelected[entryKey] ?? const <int>{})};

    final isSelected = selected.contains(tvdbId);
    final isPending = pending.contains(tvdbId);

    if (!isSelected) {
      selected.add(tvdbId);
      if (allowPending && defaultToPending) {
        pending.add(tvdbId);
      }
    } else if (allowPending && !isPending && !defaultToPending) {
      pending.add(tvdbId);
    } else if (allowPending && isPending && defaultToPending) {
      pending.remove(tvdbId);
    } else {
      selected.remove(tvdbId);
      pending.remove(tvdbId);
    }

    state = state.copyWith(
      selected: {...state.selected, entryKey: selected},
      pendingSelected: {...state.pendingSelected, entryKey: pending},
      manualPicks: {...state.manualPicks}..remove(entryKey),
    );
  }

  /// Records a "Cerca manualment" pick without applying it yet - takes
  /// effect only via confirmAll(). Clears any ticked auto-candidates for
  /// the same entry.
  void setManualPick(String entryKey, SearchResult result) {
    state = state.copyWith(
      selected: {...state.selected}..remove(entryKey),
      manualPicks: {...state.manualPicks, entryKey: result},
    );
  }

  /// Undoes a manual pick without applying it - lets the user reconsider
  /// and go back to the auto-suggested candidates (if any) instead.
  void clearManualPick(String entryKey) {
    if (!state.manualPicks.containsKey(entryKey)) return;
    state = state.copyWith(
      manualPicks: {...state.manualPicks}..remove(entryKey),
    );
  }

  /// "Confirma-ho tot": resolves every ticked/manually-picked entry one at
  /// a time (sequential, not concurrent, since each call mutates
  /// state.items/resolvedCount as it finishes).
  Future<void> confirmAll() async {
    if (state.isConfirmingAll) return;
    final toConfirm = state.items
        .where(
          (entry) =>
              (state.selected[entry.key]?.isNotEmpty ?? false) ||
              state.manualPicks.containsKey(entry.key),
        )
        .toList();
    if (toConfirm.isEmpty) return;

    state = state.copyWith(isConfirmingAll: true);
    for (final entry in toConfirm) {
      final manualPick = state.manualPicks[entry.key];
      if (manualPick != null) {
        await resolveWithResult(entry, manualPick);
        continue;
      }
      final tvdbIds = state.selected[entry.key];
      if (tvdbIds == null || tvdbIds.isEmpty) continue;
      await resolve(
        entry,
        tvdbIds.toList(),
        pendingTvdbIds: state.pendingSelected[entry.key] ?? const {},
      );
    }
    state = state.copyWith(isConfirmingAll: false);
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

  /// Backs "Surt sense confirmar": discards every ticked candidate and
  /// manual pick.
  void clearAllSelections() {
    if (state.selected.isEmpty &&
        state.pendingSelected.isEmpty &&
        state.manualPicks.isEmpty) {
      return;
    }
    state = state.copyWith(
      selected: const {},
      pendingSelected: const {},
      manualPicks: const {},
    );
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
      selected: {...state.selected}..remove(key),
      pendingSelected: {...state.pendingSelected}..remove(key),
      manualPicks: {...state.manualPicks}..remove(key),
    );
    // keeps the Perfil badge/nav count in sync without waiting for the next
    // pendingCountProvider poll
    ref.read(pendingCountProvider.notifier).decrement();
  }

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
