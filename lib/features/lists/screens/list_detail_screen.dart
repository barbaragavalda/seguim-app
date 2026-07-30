import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../search/data/series.dart';
import '../data/list_movie.dart';
import '../providers/list_detail_provider.dart';

class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({super.key, required this.listId, required this.name});

  final int listId;
  final String name;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  static const _loadMoreThreshold = 300;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as the other detail
    // screens' initState (SeriesDetailScreen, MySeriesScreen, ...)
    Future.microtask(
      () => ref.read(listDetailProvider.notifier).load(widget.listId, widget.name),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(listDetailProvider.notifier).loadMore();
      ref.read(listDetailProvider.notifier).loadMoreMovies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(listDetailProvider);
    final name = state.name.isEmpty ? widget.name : state.name;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _rename(context, name),
          child: Text(name),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addSeriesTooltip,
            onPressed: () => context.push('/lists/${widget.listId}/add'),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, l10n, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ListDetailState state,
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
    if (state.items.isEmpty && state.movieItems.isEmpty && state.pendingCount == 0) {
      return Center(child: Text(l10n.listDetailEmpty));
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (state.pendingCount > 0) _PendingBanner(count: state.pendingCount, l10n: l10n),
        if (state.items.isNotEmpty) ...[
          _SectionHeader(title: l10n.navWatchlist),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _DraggableSeriesCard(
                  series: state.items[index],
                  l10n: l10n,
                ),
                childCount: state.items.length,
              ),
            ),
          ),
          if (state.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
        if (state.movieItems.isNotEmpty) ...[
          _SectionHeader(title: l10n.navMovies),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.5,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _DraggableMovieCard(
                  movie: state.movieItems[index],
                  l10n: l10n,
                ),
                childCount: state.movieItems.length,
              ),
            ),
          ),
          if (state.isLoadingMoreMovies)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _rename(BuildContext context, String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    String? errorText;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(l10n.renameListTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.listNameLabel,
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                // guards against Navigator.pop() firing twice (e.g. a
                // double-tap): the dialog element stays mounted for the
                // whole exit animation after the first pop, so a second
                // in-flight save could otherwise pop something else once
                // it resolves - see go_router "popped the last page" crash
                onPressed: isSaving
                    ? null
                    : () async {
                        setState(() => isSaving = true);
                        final error = await ref
                            .read(listDetailProvider.notifier)
                            .renameList(controller.text.trim());
                        if (error == null) {
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } else {
                          setState(() {
                            isSaving = false;
                            errorText = error == 'unknown_error'
                                ? l10n.genericError
                                : error;
                          });
                        }
                      },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Drop-onto-me-to-insert-after-me: wraps each poster in a DragTarget so
/// dropping another card here calls reorderSerie(dragged, afterTvdbId:
/// this card's own tvdbId) - matches the backend's neighbor-based
/// reordering exactly, no separate "full order" submission needed.
class _DraggableSeriesCard extends ConsumerWidget {
  const _DraggableSeriesCard({required this.series, required this.l10n});

  final Series series;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _SeriesCard(series: series, l10n: l10n);

    return DragTarget<Series>(
      onWillAcceptWithDetails: (details) => details.data.tvdbId != series.tvdbId,
      onAcceptWithDetails: (details) {
        ref
            .read(listDetailProvider.notifier)
            .reorderSerie(details.data.tvdbId, afterTvdbId: series.tvdbId);
      },
      builder: (context, candidateData, rejectedData) {
        return Opacity(
          opacity: candidateData.isNotEmpty ? 0.4 : 1,
          child: LongPressDraggable<Series>(
            data: series,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 140,
                child: SeriesPoster(imageUrl: series.imageUrl),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: card,
          ),
        );
      },
    );
  }
}

class _SeriesCard extends ConsumerWidget {
  const _SeriesCard({required this.series, required this.l10n});

  final Series series;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = series.year;
    final status = series.status == null
        ? null
        : localizedSeriesStatus(l10n, series.status!);
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () => context.push('/series/${series.tvdbId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SeriesPoster(imageUrl: series.imageUrl),
              Positioned(
                top: 4,
                right: 4,
                child: _RemoveButton(
                  onTap: () => ref
                      .read(listDetailProvider.notifier)
                      .removeSerie(series.tvdbId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            series.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          if (year != null || status != null)
            Row(
              children: [
                if (year != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(year, style: subtitleStyle),
                  ),
                if (status != null)
                  Flexible(
                    child: StatusTag(
                      label: status,
                      color: seriesStatusColor(series.status!),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}

/// Shown when TvTimeImport::Processor couldn't confidently resolve one or
/// more of this list's own series/movies (a dead/renumbered tvdb_id with no
/// name match, or several same-titled TheTVDB candidates) - see
/// series_import_pending_list/movie_import_pending_list's own docblocks in
/// db.sql. Tapping it opens the same pending-resolution screen every other
/// unresolved import item already goes through - it isn't scoped to just
/// this list's own items, but resolving any of them updates this count on
/// the next visit either way.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.l10n});

  final int count;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/import/pending'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.question_mark,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.listPendingItemsBanner(count),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list's series and movies are two separate grids (own independent
/// ordering/pagination - see ListDetailController's own docblock), each
/// under its own small heading rather than mixed into one grid.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

/// Mirrors _DraggableSeriesCard exactly, for this list's own movies -
/// dropping onto me calls reorderMovie(dragged, afterTvdbId: my own
/// tvdbId), same neighbor-based reordering as the series grid.
class _DraggableMovieCard extends ConsumerWidget {
  const _DraggableMovieCard({required this.movie, required this.l10n});

  final ListMovie movie;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = _MovieCard(movie: movie, l10n: l10n);

    return DragTarget<ListMovie>(
      onWillAcceptWithDetails: (details) => details.data.tvdbId != movie.tvdbId,
      onAcceptWithDetails: (details) {
        ref
            .read(listDetailProvider.notifier)
            .reorderMovie(details.data.tvdbId, afterTvdbId: movie.tvdbId);
      },
      builder: (context, candidateData, rejectedData) {
        return Opacity(
          opacity: candidateData.isNotEmpty ? 0.4 : 1,
          child: LongPressDraggable<ListMovie>(
            data: movie,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 140,
                child: SeriesPoster(imageUrl: movie.imageUrl),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: card,
          ),
        );
      },
    );
  }
}

class _MovieCard extends ConsumerWidget {
  const _MovieCard({required this.movie, required this.l10n});

  final ListMovie movie;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = movie.year;
    final status = movie.status == null
        ? null
        : localizedMovieStatus(l10n, movie.status!);
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () => context.push('/movies/${movie.tvdbId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SeriesPoster(imageUrl: movie.imageUrl),
              Positioned(
                top: 4,
                right: 4,
                child: _RemoveButton(
                  onTap: () => ref
                      .read(listDetailProvider.notifier)
                      .removeMovie(movie.tvdbId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            movie.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          if (year != null || status != null)
            Row(
              children: [
                if (year != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(year, style: subtitleStyle),
                  ),
                if (status != null)
                  Flexible(
                    child: StatusTag(
                      label: status,
                      color: movieStatusColor(movie.status!),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
