import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../search/data/search_result.dart';
import '../data/pending_entry.dart';
import '../providers/pending_resolution_provider.dart';
import '../providers/tvtime_import_provider.dart';

/// The three ways out of the "you have unconfirmed ticks" dialog - see
/// _PendingResolutionScreenState._confirmExitIfNeeded()'s own docblock.
/// Cancel isn't a value here since dismissing/cancelling the dialog already
/// returns null on its own.
enum _ExitChoice { confirmAll, discard }

/// Lets the user resolve series/movie titles a TV Time import couldn't
/// confidently match on its own - each with up to 5 TheTVDB candidates
/// (poster + year) to tap, or a "skip" if none are right. Mirrors the same
/// pattern several other TV Time migration tools converged on independently
/// (see Api\Model\TvTimeImport\MovieMatcher/SeriesMatcher's own docblocks).
class PendingResolutionScreen extends ConsumerStatefulWidget {
  const PendingResolutionScreen({super.key});

  @override
  ConsumerState<PendingResolutionScreen> createState() =>
      _PendingResolutionScreenState();
}

class _PendingResolutionScreenState
    extends ConsumerState<PendingResolutionScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as every other screen's
    // initState in this app
    Future.microtask(() => ref.read(pendingResolutionProvider.notifier).load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // resolving/skipping while a batch is still adding new pending entries
    // in the background is confusing (the list you're working through can
    // change under you) and racy (a resolve could land on an entry a
    // still-running batch is about to touch itself) - simplest fix is to
    // not let the user in here at all while importing == true, regardless
    // of which of this screen's several entry points they came from
    final importing =
        ref.watch(tvTimeImportProvider.select((s) => s.phase)) ==
        TvTimeImportPhase.processing;
    if (importing) {
      return _ImportInProgressView(l10n: l10n);
    }

    final state = ref.watch(pendingResolutionProvider);

    ref.listen(pendingResolutionProvider, (previous, next) {
      final actionErrorKey = next.actionErrorKey;
      if (actionErrorKey != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_actionErrorMessage(l10n, actionErrorKey))),
        );
        // consumed - clear it so navigating away and back (or the next
        // rebuild) doesn't re-show the same SnackBar
        ref.read(pendingResolutionProvider.notifier).clearActionError();
      }

      // confirmAll() just finished (isConfirmingAll true -> false) - jump
      // back to the top of the list, since every entry the user was
      // looking at is gone now and what's left (or the "all done" empty
      // state) starts there. Not needed for the "confirm and leave" exit-
      // dialog path (_confirmExitIfNeeded) - that one pops the screen
      // outright once confirmAll() resolves, so there's nothing left here
      // to scroll.
      if (previous?.isConfirmingAll == true &&
          !next.isConfirmingAll &&
          _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return PopScope(
      // blocks the pop only while something's ticked but not yet confirmed,
      // or while confirmAll() is still working through them - see
      // _confirmExitIfNeeded()'s own docblock
      canPop: state.selectedEntryCount == 0 && !state.isConfirmingAll,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitIfNeeded(context, l10n, state.selectedEntryCount);
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(l10n.pendingMoviesTitle),
              actions: [
                if (state.total > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Center(
                      child: Text(
                        '${state.resolvedCount}/${state.total}',
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(child: _buildBody(context, l10n, state)),
            bottomNavigationBar: state.selectedEntryCount > 0
                ? _ConfirmAllBar(count: state.selectedEntryCount, l10n: l10n)
                : null,
          ),
          // covers the whole screen (cards, buttons, the "Surt" back arrow)
          // while confirmAll() works through every ticked entry one at a
          // time - this can take a real while for many items (each one is
          // its own TheTVDB sync), and without this the screen just sits
          // there looking unresponsive rather than visibly busy
          if (state.isConfirmingAll)
            _ConfirmingAllOverlay(
              resolvedCount: state.resolvedCount,
              total: state.total,
              l10n: l10n,
            ),
        ],
      ),
    );
  }

  /// Backs the "asks before leaving with unconfirmed ticks" half of the
  /// request - a plain pop would otherwise silently throw away every
  /// candidate the user had already ticked (but not yet hit Confirma for)
  /// the moment they navigate away, with no way back. Offers the same
  /// three ways out a modified-form dialog would: confirm everything ticked
  /// and then leave, leave without confirming (discarding the ticks), or
  /// stay on the screen.
  Future<void> _confirmExitIfNeeded(
    BuildContext context,
    AppLocalizations l10n,
    int selectedEntryCount,
  ) async {
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmBeforeLeavingTitle),
        content: Text(l10n.confirmBeforeLeavingBody(selectedEntryCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ExitChoice.discard),
            child: Text(l10n.leaveWithoutConfirmingAction),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ExitChoice.confirmAll),
            child: Text(l10n.confirmAllAndLeaveAction),
          ),
        ],
      ),
    );

    if (!context.mounted || choice == null) return;
    if (choice == _ExitChoice.confirmAll) {
      await ref.read(pendingResolutionProvider.notifier).confirmAll();
    } else {
      ref.read(pendingResolutionProvider.notifier).clearAllSelections();
    }
    if (context.mounted) context.pop();
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    PendingResolutionState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorKey != null) {
      return Center(
        child: Text(
          state.errorKey == 'unknown_error' ? l10n.genericError : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.sage,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check,
                size: 28,
                color: AppColors.onSageLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.pendingMoviesAllDone,
              style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.items.length,
      itemBuilder: (context, index) => _PendingEntryCard(
        // keyed by the entry's own compound key, not the list index - once
        // an item is resolved/skipped and removed, the next one shifts into
        // the same index; this key is what lets Flutter tell that shift
        // apart from "this index's own entry changed" and animate/diff the
        // list correctly instead of just reusing whatever was at that index
        key: ValueKey(state.items[index].key),
        entry: state.items[index],
        busy: state.busyKeys.contains(state.items[index].key),
        l10n: l10n,
      ),
    );
  }
}

/// Candidates are tap-to-toggle rather than tap-to-resolve - more than one
/// can be selected at once (relevant for a movie entry - e.g. "Mulan" 1998
/// and 2020, both watched under TV Time's one ambiguous entry - see
/// PendingMoviesApi.resolve()'s own docblock), confirmed with the explicit
/// button once the selection is right (or the global "Confirma-ho tot" bar),
/// so a stray tap never applies the wrong series/movie by itself.
///
/// A plain ConsumerWidget rather than a ...State with its own local
/// selection - see PendingResolutionState.selected's own docblock on why
/// that selection now lives in the provider instead.
class _PendingEntryCard extends ConsumerWidget {
  const _PendingEntryCard({
    super.key,
    required this.entry,
    required this.busy,
    required this.l10n,
  });

  final PendingEntry entry;
  final bool busy;
  final AppLocalizations l10n;

  // a comfortable, fixed poster width - see the Wrap below for why this is
  // fixed rather than dividing the available width by candidate count
  static const double _candidateWidth = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      pendingResolutionProvider.select(
        (s) => s.selected[entry.key] ?? const <int>{},
      ),
    );
    final pendingSelected = ref.watch(
      pendingResolutionProvider.select(
        (s) => s.pendingSelected[entry.key] ?? const <int>{},
      ),
    );
    final manualPick = ref.watch(
      pendingResolutionProvider.select((s) => s.manualPicks[entry.key]),
    );
    // a "Cerca manualment" search prefilled with this entry's own title
    // (see SearchScreen's own initState) very often just re-finds one of
    // the very candidates already suggested below - without this, picking
    // that one would show it twice: once as the manual pick, once again
    // in the auto-suggested grid. Only actually the same show/movie if the
    // kind matches too (tvdb_id spaces for series/movies are independent,
    // so a numeric collision across kinds means nothing)
    final manualPickSameKind = manualPick != null &&
        (entry.kind == PendingEntryKind.series) ==
            (manualPick.type == SearchResultType.series);
    final visibleCandidates = manualPickSameKind
        ? entry.candidates
              .where((c) => c.tvdbId.toString() != manualPick.tvdbId)
              .toList()
        : entry.candidates;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.kind == PendingEntryKind.series
                    ? Icons.tv
                    : Icons.videocam,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  entry.title,
                  style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_subtitle(context, entry, l10n), style: subtitleStyle),
          const SizedBox(height: AppSpacing.sm),
          if (entry.candidates.isEmpty && manualPick == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                l10n.pendingMoviesNoCandidates,
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),
            )
          else
            // fixed-width candidates that wrap onto more rows as needed,
            // rather than a Row of Expanded()s - those stretched to fill
            // the container either way, so 5 candidates on a phone were
            // tiny and 2 candidates on a wide/web screen were huge. A fixed
            // size wraps once the row runs out of room and never stretches
            // when there's little to show, at any screen size.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // the "Cerca manualment" pick (if any) always shows first
                // and always reads as selected - tapping it again clears it
                // (same toggle feel as an auto-candidate), which is the
                // only way back to the auto-suggested grid below without
                // going through search again
                if (manualPick != null)
                  _CandidateTile(
                    width: _candidateWidth,
                    imageUrl: manualPick.imageUrl,
                    label: manualPick.year ?? manualPick.name,
                    selection: _CandidateSelection.watched,
                    onTap: busy
                        ? null
                        : () => ref
                              .read(pendingResolutionProvider.notifier)
                              .clearManualPick(entry.key),
                  ),
                for (final candidate in visibleCandidates)
                  _CandidateTile(
                    width: _candidateWidth,
                    imageUrl: candidate.imageUrl,
                    label: candidate.year ?? candidate.name,
                    selection: !selected.contains(candidate.tvdbId)
                        ? _CandidateSelection.none
                        : pendingSelected.contains(candidate.tvdbId)
                        ? _CandidateSelection.pending
                        : _CandidateSelection.watched,
                    onTap: busy
                        ? null
                        : () => ref
                              .read(pendingResolutionProvider.notifier)
                              .toggleCandidate(
                                entry.key,
                                candidate.tvdbId,
                                allowPending:
                                    entry.kind == PendingEntryKind.movie,
                                defaultToPending:
                                    entry.kind == PendingEntryKind.movie &&
                                    !entry.movie!.watched,
                              ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => context.push('/import/pending/resolve', extra: entry),
                child: Text(
                  l10n.searchManuallyAction,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => ref.read(pendingResolutionProvider.notifier).skip(entry),
                child: Text(
                  l10n.skipAction,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context, PendingEntry entry, AppLocalizations l10n) {
    if (entry.kind == PendingEntryKind.series) {
      final count = entry.series!.episodesWatchedCount;
      return count > 0
          ? l10n.pendingSeriesEpisodesWatched(count)
          : l10n.pendingMovieFromWatchlist;
    }

    final movie = entry.movie!;
    if (movie.watched && movie.watchedAt != null) {
      final date = DateTime.tryParse(movie.watchedAt!);
      if (date != null) {
        final locale = Localizations.localeOf(context).toString();
        return l10n.pendingMovieWatchedOn(
          DateFormat('d MMM y', locale).format(date),
        );
      }
    }
    return l10n.pendingMovieFromWatchlist;
  }
}

/// Maps the backend's own action-error codes (see ResolvePendingSeries/
/// ResolvePendingMovie's own docblocks) to a user-facing message - anything
/// unrecognized (a raw validation message, or 'unknown_error') falls back
/// to the same generic error text the rest of the app uses.
String _actionErrorMessage(AppLocalizations l10n, String errorKey) {
  switch (errorKey) {
    case 'candidate_unavailable':
      return l10n.resolveCandidateUnavailable;
    case '404':
      return l10n.resolveActionNotFound;
    default:
      return l10n.genericError;
  }
}

/// Persistent bottom bar that resolves every currently-ticked entry at once
/// - the "farragós" one-by-one Confirma the user was asking to avoid. Only
/// shown once at least one card has a candidate ticked (see the Scaffold's
/// own bottomNavigationBar).
class _ConfirmingAllOverlay extends StatelessWidget {
  const _ConfirmingAllOverlay({
    required this.resolvedCount,
    required this.total,
    required this.l10n,
  });

  final int resolvedCount;
  final int total;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        // this Stack sibling sits outside Scaffold's own Material, so
        // without one of its own here, Text/CircularProgressIndicator fall
        // back to Flutter's raw un-themed defaults (huge text, debug
        // underline) instead of the app's actual theme
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.confirmingAllProgress(resolvedCount, total),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmAllBar extends ConsumerWidget {
  const _ConfirmAllBar({required this.count, required this.l10n});

  final int count;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConfirmingAll = ref.watch(
      pendingResolutionProvider.select((s) => s.isConfirmingAll),
    );
    final pendingCandidates = ref.watch(
      pendingResolutionProvider.select((s) => s.pendingCandidateCount),
    );
    final watchedCandidates = ref.watch(
      pendingResolutionProvider.select((s) => s.watchedCandidateCount),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isConfirmingAll
                ? null
                : () =>
                      ref.read(pendingResolutionProvider.notifier).confirmAll(),
            child: isConfirmingAll
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                // the split wording only makes sense once at least one
                // candidate is actually going to end up "pendent de veure" -
                // for the common case (every selection a plain "vist", no
                // ambiguity to split) the plain X-seleccionats count reads
                // better than "X ja vistes i 0 per veure"
                : Text(
                    pendingCandidates > 0
                        ? l10n.confirmAllSplitAction(
                            watchedCandidates,
                            pendingCandidates,
                          )
                        : l10n.confirmAllAction(count),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A candidate tile's three states - see PendingResolutionState.
/// pendingSelected's own docblock. `watched`/`pending` share the same
/// "ticked, will be applied on confirm" meaning as far as selectedEntryCount
/// etc. are concerned; they only differ in which watch status the backend
/// gives the candidate once resolved.
enum _CandidateSelection { none, watched, pending }

/// One poster+label tile in a pending entry's candidate grid - shared by
/// both the auto-suggested candidates and the "Cerca manualment" pick (see
/// _PendingEntryCard's own Wrap), since the two only ever differ in where
/// their data comes from (PendingMovieCandidate vs SearchResult), not in
/// how they're drawn or toggled.
class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.width,
    required this.imageUrl,
    required this.label,
    required this.selection,
    required this.onTap,
  });

  final double width;
  final String? imageUrl;
  final String label;
  final _CandidateSelection selection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // sage+check reads as "vist" (a real watched_at gets applied), coral+
    // clock as "a la teva watchlist" (added, not specifically watched) -
    // matches the same two outcomes _subtitle() already describes in text
    // for the entry as a whole, and toggleCandidate()'s own defaultToPending
    // (which of the two a candidate's first tap lands on)
    final color = switch (selection) {
      _CandidateSelection.none => null,
      _CandidateSelection.watched => AppColors.sage,
      _CandidateSelection.pending => AppColors.coral,
    };

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: imageUrl == null
                        ? const PlaceholderMark(fontSize: 15)
                        : CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const PlaceholderMark(fontSize: 15),
                            errorWidget: (context, url, error) =>
                                const PlaceholderMark(fontSize: 15),
                          ),
                  ),
                ),
                if (color != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: color, width: 3),
                      ),
                    ),
                  ),
                if (selection == _CandidateSelection.watched)
                  const Positioned(top: 4, right: 4, child: _WatchedOnBadge()),
                if (selection == _CandidateSelection.pending)
                  const Positioned(top: 4, right: 4, child: _WatchlistBadge()),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coral + clock - "a la teva watchlist" (added, no watched_at applied),
/// same color _subtitle() would describe in text for the entry as a whole.
class _WatchlistBadge extends StatelessWidget {
  const _WatchlistBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: AppColors.coral,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.schedule,
        size: 13,
        color: AppColors.onCoralLight,
      ),
    );
  }
}

/// Sage + check - "vist" (the entry's own snapshotted watched_at gets
/// applied to this candidate), same pairing _subtitle() uses in text.
class _WatchedOnBadge extends StatelessWidget {
  const _WatchedOnBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 13, color: AppColors.onSageLight),
    );
  }
}

/// Replaces the whole screen (see build()'s own `importing` check) rather
/// than just disabling the resolve/skip buttons - there's nothing useful to
/// show underneath anyway while an import batch might still be adding more
/// pending entries.
class _ImportInProgressView extends StatelessWidget {
  const _ImportInProgressView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pendingMoviesTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.hourglass_top,
                    size: 28,
                    color: AppColors.onCoralLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.pendingResolutionBlockedTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.pendingResolutionBlockedBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
