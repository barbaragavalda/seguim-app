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
  // how many have been resolved/skipped this session - used for the X/total
  // progress bar, same shape as rewatch's own Resolve screen
  final int resolvedCount;
  final Set<String> busyKeys;
  // entry.key -> the candidate tvdb_ids currently ticked for it on this
  // screen - lives here (not as local State in the card widget) so it
  // survives navigating to "Cerca manualment" and back (a provider outlives
  // the card's own widget being pushed under a new route) and so
  // confirmAll() below can see every card's selection at once, not just
  // whichever one owns the tap that triggered it
  final Map<String, Set<int>> selected;
  // entry.key -> the subset of selected[entryKey] marked "pendent de veure"
  // instead of "vist" - only meaningful for movies (a title with no release
  // date anywhere in the export can't be told apart from a same-movie
  // re-follow at import time, see TvTimeImport\Parser::parseMovies()'s own
  // docblock, so more than one real candidate can end up ticked here and
  // each needs its own watched/pending call). toggleCandidate() cycles a
  // candidate through unselected -> one ticked state -> the other ticked
  // state -> back to unselected, so this is always a subset of `selected`,
  // never wider
  final Map<String, Set<int>> pendingSelected;
  // entry.key -> a result picked via "Cerca manualment" for it, held here
  // rather than applied immediately - same reasoning as `selected` above
  // (survives the round trip to SearchScreen and back, and is only actually
  // applied once the user hits Confirma). Mutually exclusive with `selected`
  // for the same entry.key - PendingResolutionController's own
  // toggleCandidate()/setManualPick() each clear the other, so an entry is
  // never "half auto-candidate, half manual pick" at once
  final Map<String, SearchResult> manualPicks;
  // true while confirmAll() is working through every selected entry - a
  // coarser flag than busyKeys (which is per-entry) so the global button
  // itself can show a spinner and disable re-tapping mid-run
  final bool isConfirmingAll;
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

  // how many entries currently have at least one candidate ticked (or a
  // manual pick, see `manualPicks` own docblock on why these never overlap)
  // - the global "Confirma-ho tot" button's own visibility/count
  int get selectedEntryCount =>
      selected.values.where((s) => s.isNotEmpty).length + manualPicks.length;

  // ticked candidates (across every entry) that will end up "pendent de
  // veure" - always 0 for a series-only selection, see pendingSelected's
  // own docblock. Used for the "Confirma-ho tot" button's own X vist / Y
  // pendent breakdown
  int get pendingCandidateCount =>
      pendingSelected.values.fold(0, (sum, ids) => sum + ids.length);

  // ticked candidates (across every entry) that will end up "vist" - every
  // manual pick counts as one (see resolveWithResult()'s own docblock: it
  // always applies the entry's full snapshot, same as a "vist" candidate
  // would), plus every ticked candidate not already counted in
  // pendingCandidateCount above
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

  /// Safe to call again on an already-loaded screen (ProfileScreen polls
  /// this same provider for its own pending-count badge - see its own
  /// docblock on why): re-fetching must not discard whatever the user has
  /// already ticked/picked on this screen, so `selected`/`manualPicks`/
  /// `busyKeys` survive a reload, just filtered down to entries the fresh
  /// list still has (an entry gone from the new list - resolved elsewhere,
  /// or by this same poll racing a resolve() - can't stay half-selected).
  /// `resolvedCount` is likewise left alone rather than reset to 0, so the
  /// X/total progress bar doesn't visibly jump backwards on every poll.
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

  /// [tvdbIds] can have more than one entry for a movie - see
  /// PendingMoviesApi.resolve()'s own docblock on why (e.g. "Mulan" 1998 and
  /// 2020). [pendingTvdbIds] (a subset of [tvdbIds]) marks which of those
  /// should be added as "pendent de veure" instead of "vist" - only ever
  /// non-empty for a movie, see PendingResolutionState.pendingSelected's own
  /// docblock. A series never genuinely needs more than one candidate and
  /// never uses this split, but the request shape stays the same either way.
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

  /// Cycles one candidate for [entryKey] through three states on each tap -
  /// every candidate starts unselected (load() no longer pre-ticks any of
  /// them - the user asked for "per defecte" to mean only which state the
  /// *first* tap lands on, not that everything should already look ticked
  /// before any tap at all). [allowPending] gates whether there even is a
  /// second ticked state - false for a series candidate, whose watch history
  /// is per-episode, not per-candidate-resolve, so the cycle there is just
  /// unselected -> selected -> back to unselected.
  ///
  /// [defaultToPending] flips which of the two ticked states the first tap
  /// lands on: false (the entry's own TV Time snapshot really was watched)
  /// -> unselected -> "vist" -> "pendent de veure" -> unselected; true (it
  /// was only ever added to the watchlist) -> unselected -> "pendent de
  /// veure" -> "vist" -> unselected. Ignored when [allowPending] is false.
  ///
  /// The card's own selection no longer lives in its widget State (see
  /// PendingResolutionState.selected's own docblock on why). Clears any
  /// manual pick for the same entry - see PendingResolutionState.
  /// manualPicks's own docblock on why the two are mutually exclusive.
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

  /// Records a "Cerca manualment" pick for [entryKey] without applying it
  /// yet - the search screen calls this instead of resolveWithResult()
  /// directly, so the pick only takes effect once the user hits Confirma
  /// (individually not possible anymore - only via confirmAll(), see
  /// PendingResolutionScreen's own docblock on why the per-card button was
  /// removed). Clears any ticked auto-candidates for the same entry, same
  /// mutual-exclusion reasoning as toggleCandidate() above.
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

  /// Resolves every entry that currently has at least one candidate ticked
  /// or a manual pick, one at a time - the "Confirma-ho tot" global action,
  /// so the user doesn't have to tap each card's own Confirma individually.
  /// Sequential rather than concurrent: each resolve()/resolveWithResult()
  /// already mutates state.items/resolvedCount as it finishes, and running
  /// them one after another keeps that trail of updates (and any one
  /// entry's own error) easy to follow instead of several racing at once.
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

  /// Discards every currently-ticked candidate and manual pick across every
  /// card - backs "Surt sense confirmar" in the leave-with-unconfirmed-ticks
  /// dialog, so coming back to this screen later doesn't find the same
  /// candidates still ticked from a selection the user explicitly chose to
  /// abandon.
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
    // keeps the Perfil badge/row (and the nav bar's own copy of the same
    // count) in sync in real time - without this it only caught up once
    // pendingCountProvider.notifier.load() happened to run again on its
    // own (login, selecting the Perfil tab, ...), which popping straight
    // back from this screen to an already-mounted ProfileScreen underneath
    // never triggers on its own
    ref.read(pendingCountProvider.notifier).decrement();
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
