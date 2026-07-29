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
import '../data/pending_entry.dart';
import '../providers/pending_resolution_provider.dart';

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

    return Scaffold(
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
    );
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
        // the same index; without this key Flutter reuses the removed
        // card's State (and its _selected set) for whatever entry now
        // occupies that index, instead of starting the new card fresh
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
/// button once the selection is right, so a stray tap never applies the
/// wrong series/movie by itself.
class _PendingEntryCard extends ConsumerStatefulWidget {
  const _PendingEntryCard({
    super.key,
    required this.entry,
    required this.busy,
    required this.l10n,
  });

  final PendingEntry entry;
  final bool busy;
  final AppLocalizations l10n;

  @override
  ConsumerState<_PendingEntryCard> createState() => _PendingEntryCardState();
}

class _PendingEntryCardState extends ConsumerState<_PendingEntryCard> {
  // a comfortable, fixed poster width - see the Wrap below for why this is
  // fixed rather than dividing the available width by candidate count
  static const double _candidateWidth = 96;

  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final entry = widget.entry;
    final busy = widget.busy;
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
          Text(_subtitle(context), style: subtitleStyle),
          const SizedBox(height: AppSpacing.sm),
          if (entry.candidates.isEmpty)
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
                for (final candidate in entry.candidates)
                  SizedBox(
                    width: _candidateWidth,
                    child: GestureDetector(
                      onTap: busy
                          ? null
                          : () => setState(() {
                              if (!_selected.remove(candidate.tvdbId)) {
                                _selected.add(candidate.tvdbId);
                              }
                            }),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: candidate.imageUrl == null
                                      ? const PlaceholderMark(fontSize: 15)
                                      : CachedNetworkImage(
                                          imageUrl: candidate.imageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const PlaceholderMark(fontSize: 15),
                                          errorWidget: (context, url, error) =>
                                              const PlaceholderMark(fontSize: 15),
                                        ),
                                ),
                              ),
                              if (_selected.contains(candidate.tvdbId))
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(
                                        color: AppColors.sage,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_selected.contains(candidate.tvdbId))
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: _CheckBadge(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            candidate.year ?? candidate.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          if (_selected.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy
                    ? null
                    : () => ref
                          .read(pendingResolutionProvider.notifier)
                          .resolve(entry, _selected.toList()),
                child: Text(l10n.confirmSelectionAction),
              ),
            ),
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

  String _subtitle(BuildContext context) {
    final entry = widget.entry;
    if (entry.kind == PendingEntryKind.series) {
      final count = entry.series!.episodesWatchedCount;
      return count > 0
          ? widget.l10n.pendingSeriesEpisodesWatched(count)
          : widget.l10n.pendingMovieFromWatchlist;
    }

    final movie = entry.movie!;
    if (movie.watched && movie.watchedAt != null) {
      final date = DateTime.tryParse(movie.watchedAt!);
      if (date != null) {
        final locale = Localizations.localeOf(context).toString();
        return widget.l10n.pendingMovieWatchedOn(
          DateFormat('d MMM y', locale).format(date),
        );
      }
    }
    return widget.l10n.pendingMovieFromWatchlist;
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
