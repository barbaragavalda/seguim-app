import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../import/data/pending_entry.dart';
import '../../import/providers/pending_resolution_provider.dart';
import '../../lists/providers/list_detail_provider.dart';
import '../data/search_result.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.addToListId, this.resolveEntry});

  /// Non-null when pushed as an "add to this list" picker (see
  /// ListDetailScreen's "+" button) instead of the bottom-tab Search
  /// screen - tapping a result toggles it in/out of listDetailProvider's
  /// currently-loaded list (as a series or a movie, whichever the result
  /// is) instead of navigating to detail.
  final int? addToListId;

  /// Non-null when pushed as a "find the right match by hand" picker for
  /// one specific PendingResolutionScreen entry (its own MovieMatcher/
  /// SeriesMatcher search came back with too few/no usable candidates -
  /// see that screen's own "Cerca manualment" action). Results include
  /// both series and movies regardless of this entry's own kind - TV
  /// Time's own "shows" vs "movies" split doesn't always match TheTVDB's
  /// (e.g. a TV movie tracked as a one-episode "show"), so the user needs
  /// to be able to find and pick whichever one actually exists. Tapping a
  /// result resolves the entry immediately (see
  /// PendingResolutionController.resolveWithResult()) instead of
  /// navigating to its detail.
  final PendingEntry? resolveEntry;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _searchBarClearance = 76.0;

  final _queryController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _queryController.addListener(_onQueryTextChanged);
    // pre-fill and immediately search with the pending entry's own title -
    // the user already typed this once (it's TV Time's own name for it),
    // no reason to make them type it again
    final resolveEntry = widget.resolveEntry;
    if (resolveEntry != null) {
      _queryController.text = resolveEntry.title;
      Future.microtask(
        () => ref.read(searchProvider.notifier).onQueryChanged(resolveEntry.title),
      );
    }
  }

  void _onQueryTextChanged() {
    setState(() {});
  }

  void _clearQuery() {
    _queryController.clear();
    ref.read(searchProvider.notifier).onQueryChanged('');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _queryController.removeListener(_onQueryTextChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      appBar: widget.addToListId != null
          ? AppBar(title: Text(l10n.addSeriesTooltip))
          : widget.resolveEntry != null
              ? AppBar(title: Text(l10n.resolveManuallyTitle))
              : null,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildBody(context, l10n, searchState),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _queryController,
                onChanged: (value) =>
                    ref.read(searchProvider.notifier).onQueryChanged(value),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearQuery,
                        ),
                  hintText: l10n.searchPlaceholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    SearchState state,
  ) {
    if (state.query.trim().isEmpty) {
      return Center(child: Text(l10n.searchPlaceholder));
    }
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorKey != null) {
      return Center(
        child: Text(
          state.errorKey == 'unknown_error'
              ? l10n.genericError
              : state.errorKey!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    // deliberately unfiltered even when resolving a pending entry - TV
    // Time's own "shows" vs "movies" split doesn't always match TheTVDB's
    // (e.g. a TV movie tracked as a one-episode "show"), so the user needs
    // to be able to find and pick either kind regardless of which one the
    // import guessed - see PendingResolutionController.resolveWithResult()'s
    // own docblock
    final resolveEntry = widget.resolveEntry;
    final results = state.results;

    if (results.isEmpty) {
      return Center(child: Text(l10n.searchNoResults(state.query)));
    }

    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: _searchBarClearance)),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.5,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final result = results[index];
            final isMovie = result.type == SearchResultType.movie;
            final year = result.year;
            final status = result.status == null
                ? null
                : (isMovie
                      ? localizedMovieStatus(l10n, result.status!)
                      : localizedSeriesStatus(l10n, result.status!));
            final subtitleStyle = Theme.of(context).textTheme.bodySmall;
            final addToListId = widget.addToListId;
            final inList = addToListId != null &&
                ref.watch(
                  listDetailProvider.select(
                    (s) => isMovie
                        ? s.movieItems.any((m) => m.tvdbId == result.tvdbId)
                        : s.items.any((i) => i.tvdbId == result.tvdbId),
                  ),
                );
            return GestureDetector(
              onTap: () {
                if (resolveEntry != null) {
                  ref
                      .read(pendingResolutionProvider.notifier)
                      .resolveWithResult(resolveEntry, result);
                  context.pop();
                  return;
                }
                if (addToListId == null) {
                  context.push(
                    isMovie ? '/movies/${result.tvdbId}' : '/series/${result.tvdbId}',
                  );
                  return;
                }
                final notifier = ref.read(listDetailProvider.notifier);
                if (isMovie) {
                  if (inList) {
                    notifier.removeMovie(result.tvdbId);
                  } else {
                    notifier.addMovie(movieFromSearchResult(result));
                  }
                } else {
                  if (inList) {
                    notifier.removeSerie(result.tvdbId);
                  } else {
                    notifier.addSerie(seriesFromSearchResult(result));
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      isMovie
                          ? _MoviePoster(imageUrl: result.imageUrl)
                          : SeriesPoster(imageUrl: result.imageUrl),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: _TypeBadge(isMovie: isMovie),
                      ),
                      if (inList)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: _InListBadge(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.name,
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
                              color: isMovie
                                  ? movieStatusColor(result.status!)
                                  : seriesStatusColor(result.status!),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          }, childCount: results.length),
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// Same shape as the shared SeriesPoster widget - kept local rather than
/// generalizing that one, since it's used in several series-specific
/// places this pass doesn't need to touch. Keeps the same "S!" placeholder
/// mark as a series (rather than a movie-specific one) when there's no
/// image - the two card types sit side by side in this same grid, and the
/// _TypeBadge already tells them apart, so a second, differing placeholder
/// mark would only read as an inconsistency.
class _MoviePoster extends StatelessWidget {
  const _MoviePoster({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: imageUrl == null
            ? const PlaceholderMark()
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const PlaceholderMark(),
                errorWidget: (context, url, error) => const PlaceholderMark(),
              ),
      ),
    );
  }
}

/// Bottom-left badge over the poster telling a movie result apart from a
/// series one at a glance - same icon vocabulary as the bottom nav bar
/// (Icons.tv for series, Icons.videocam for movies).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isMovie});

  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMovie ? Icons.videocam : Icons.tv,
        size: 13,
        color: Colors.white,
      ),
    );
  }
}

class _InListBadge extends StatelessWidget {
  const _InListBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 14, color: AppColors.onSageLight),
    );
  }
}
