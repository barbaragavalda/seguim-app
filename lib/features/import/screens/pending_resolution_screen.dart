import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../search/data/search_result.dart';
import '../data/pending_entry.dart';
import '../providers/pending_resolution_provider.dart';
import '../providers/tvtime_import_provider.dart';

/// No `cancel` value - dismissing the dialog already returns null.
enum _ExitChoice { confirmAll, discard }

/// Lets the user resolve series/movie titles a TV Time import couldn't
/// confidently match, picking from up to 5 TheTVDB candidates or skipping.
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
    // defer: can't modify provider state during build
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

    // block entry entirely while a batch import is still running - resolving
    // mid-batch is racy (a still-running import can touch the same entry)
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
        // clear so it doesn't re-show on the next rebuild
        ref.read(pendingResolutionProvider.notifier).clearActionError();
      }

      // after confirmAll() finishes, jump back to top - resolved entries
      // are gone, so whatever's left (or the empty state) starts there
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
      // blocks pop while anything is ticked-but-unconfirmed, or confirmAll() is running
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
          // each resolve is its own TheTVDB sync, so this can take a while -
          // cover the screen rather than leave it looking unresponsive
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

  /// Asks before leaving with unconfirmed ticks, since a plain pop would
  /// silently discard them: confirm-and-leave, discard-and-leave, or stay.
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
                Symbols.check,
                size: 28,
                color: AppColors.navy,
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
        // key by entry.key, not index, so removal doesn't get read as a change
        key: ValueKey(state.items[index].key),
        entry: state.items[index],
        busy: state.busyKeys.contains(state.items[index].key),
        l10n: l10n,
      ),
    );
  }
}

/// Candidates are tap-to-toggle, not tap-to-resolve (more than one can
/// apply), applied only via the confirm button so a stray tap can't misfire.
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
    // hide the manual pick from the grid if it duplicates a candidate;
    // tvdb_id alone isn't enough since the id space is per-kind
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
                    ? Symbols.tv
                    : Symbols.local_activity,
                fill: entry.kind == PendingEntryKind.series ? 0 : 1,
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
            // fixed-width tiles that wrap, not Expanded()s stretching to
            // fill the row (tiny on phone, huge on wide screens)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // manual pick always shows first, selected; tapping it again clears it
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

/// Maps backend action-error codes to a user-facing message; anything
/// unrecognized falls back to the generic error text.
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

/// Full-screen overlay shown while confirmAll() works through every ticked
/// entry - each resolve is its own TheTVDB sync, so this can take a while.
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
        // sits outside Scaffold's Material, so needs its own or
        // Text/CircularProgressIndicator fall back to un-themed defaults
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

/// Bottom bar that resolves every ticked entry at once, replacing a
/// one-by-one confirm.
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
                // split wording only makes sense once some are "pendent" -
                // otherwise the plain count reads better
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

/// `watched`/`pending` both count as "ticked" for selectedEntryCount etc;
/// they differ only in the watch status applied once resolved.
enum _CandidateSelection { none, watched, pending }

/// Shared poster+label tile for both auto-suggested candidates and the
/// manual-search pick - they differ only in data source, not rendering.
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
    // sage+check = watched (applies watched_at), coral+clock = added to
    // watchlist only - matches _subtitle()'s wording
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

/// Coral + clock: added to watchlist, no watched_at applied.
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
        Symbols.schedule,
        size: 13,
        color: AppColors.navy,
      ),
    );
  }
}

/// Sage + check: watched, the entry's snapshotted watched_at is applied.
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
      child: const Icon(Symbols.check, size: 13, color: AppColors.navy),
    );
  }
}

/// Replaces the whole screen rather than just disabling resolve/skip -
/// nothing useful to show while a batch import might still add entries.
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
                    Symbols.hourglass_top,
                    size: 28,
                    color: AppColors.navy,
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
