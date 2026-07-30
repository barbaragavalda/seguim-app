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
  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as every other screen's
    // initState in this app
    Future.microtask(() => ref.read(pendingResolutionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(pendingResolutionProvider);

    ref.listen(pendingResolutionProvider, (previous, next) {
      final actionErrorKey = next.actionErrorKey;
      if (actionErrorKey == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_actionErrorMessage(l10n, actionErrorKey))),
      );
      // consumed - clear it so navigating away and back (or the next
      // rebuild) doesn't re-show the same SnackBar
      ref.read(pendingResolutionProvider.notifier).clearActionError();
    });

    return PopScope(
      // blocks the pop only while something's ticked but not yet confirmed
      // - see _confirmExitIfNeeded()'s own docblock
      canPop: state.selectedEntryCount == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitIfNeeded(context, l10n, state.selectedEntryCount);
      },
      child: Scaffold(
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
                    selected: true,
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
                    selected: selected.contains(candidate.tvdbId),
                    onTap: busy
                        ? null
                        : () => ref
                              .read(pendingResolutionProvider.notifier)
                              .toggleCandidate(entry.key, candidate.tvdbId),
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
class _ConfirmAllBar extends ConsumerWidget {
  const _ConfirmAllBar({required this.count, required this.l10n});

  final int count;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConfirmingAll = ref.watch(
      pendingResolutionProvider.select((s) => s.isConfirmingAll),
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
                : Text(l10n.confirmAllAction(count)),
          ),
        ),
      ),
    );
  }
}

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
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String? imageUrl;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                if (selected)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.sage, width: 3),
                      ),
                    ),
                  ),
                if (selected)
                  const Positioned(top: 4, right: 4, child: _CheckBadge()),
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

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

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
