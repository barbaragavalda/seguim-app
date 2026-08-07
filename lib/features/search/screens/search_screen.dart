import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../favorites/providers/favorite_movies_provider.dart';
import '../../favorites/providers/favorite_series_provider.dart';
import '../../import/data/pending_entry.dart';
import '../../import/providers/pending_resolution_provider.dart';
import '../../lists/providers/list_detail_provider.dart';
import '../data/search_result.dart';
import '../providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.addToListId,
    this.resolveEntry,
    this.favoritesPickerIsMovie,
  });

  /// Non-null when pushed as an "add to this list" picker: tapping a result
  /// toggles it in/out of listDetailProvider's currently-loaded list instead
  /// of navigating to detail.
  final int? addToListId;

  /// Non-null when pushed as an "add a favorite" picker - false for series,
  /// true for movies. Unlike addToListId (mixed kinds), this filters results
  /// to the matching type and favorites directly on tap.
  final bool? favoritesPickerIsMovie;

  /// Non-null when pushed as a manual-match picker for one
  /// PendingResolutionScreen entry. Includes both series and movies
  /// regardless of the entry's own kind, since TV Time's shows/movies split
  /// doesn't always match TheTVDB's. Tapping a result records it as the
  /// entry's manual pick rather than resolving immediately; it's applied
  /// only once the user hits "Confirma-ho tot".
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
    final favoritesPickerIsMovie = widget.favoritesPickerIsMovie;
    if (favoritesPickerIsMovie != null) {
      // only the matching provider - results are filtered to this one type
      Future.microtask(() {
        if (favoritesPickerIsMovie) {
          ref.read(favoriteMoviesProvider.notifier).load();
        } else {
          ref.read(favoriteSeriesProvider.notifier).load();
        }
      });
    }
    // pre-fill and search with TV Time's own title, already typed once
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
              : widget.favoritesPickerIsMovie != null
                  ? AppBar(title: Text(l10n.addFavoriteTitle))
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
                  prefixIcon: const Icon(Symbols.search),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Symbols.close),
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
    // unfiltered even when resolving a pending entry - the import's guessed
    // kind isn't always right, so the user must be able to pick either kind
    final resolveEntry = widget.resolveEntry;
    final favoritesPickerIsMovie = widget.favoritesPickerIsMovie;
    final results = favoritesPickerIsMovie == null
        ? state.results
        : state.results
              .where(
                (r) => (r.type == SearchResultType.movie) == favoritesPickerIsMovie,
              )
              .toList();

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
            final isFavorite = favoritesPickerIsMovie == null
                ? false
                : isMovie
                    ? ref.watch(
                        favoriteMoviesProvider.select(
                          (s) => s.items.any((m) => m.tvdbId == result.tvdbId),
                        ),
                      )
                    : ref.watch(
                        favoriteSeriesProvider.select(
                          (s) => s.items.any((i) => i.tvdbId == result.tvdbId),
                        ),
                      );
            return GestureDetector(
              onTap: () {
                if (resolveEntry != null) {
                  // takes effect only once "Confirma-ho tot" is hit
                  ref
                      .read(pendingResolutionProvider.notifier)
                      .setManualPick(resolveEntry.key, result);
                  context.pop();
                  return;
                }
                if (favoritesPickerIsMovie != null) {
                  if (isMovie) {
                    final notifier = ref.read(favoriteMoviesProvider.notifier);
                    if (isFavorite) {
                      notifier.remove(result.tvdbId);
                    } else {
                      notifier.add(movieFromSearchResult(result));
                    }
                  } else {
                    final notifier = ref.read(favoriteSeriesProvider.notifier);
                    if (isFavorite) {
                      notifier.remove(result.tvdbId);
                    } else {
                      notifier.add(seriesFromSearchResult(result));
                    }
                  }
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
                          : SeriesPoster(
                              imageUrl: result.imageUrl,
                              watchProgress: result.watchProgress,
                            ),
                      Positioned(
                        // same offset regardless of WatchProgressBar.height
                        // so the badge doesn't jump depending on result type
                        bottom: 10,
                        left: 4,
                        child: _TypeBadge(isMovie: isMovie),
                      ),
                      if (inList || isFavorite)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: _AddedBadge(),
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

/// Same shape as the shared SeriesPoster widget, kept local since
/// SeriesPoster is used elsewhere too. Reuses the same placeholder mark as
/// series - _TypeBadge already tells the two apart in this grid.
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

/// Same icon vocabulary as the bottom nav bar: movies filled, series
/// unfilled (except the nav bar's own selected state).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isMovie});

  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMovie ? Symbols.local_activity : Symbols.tv,
        fill: isMovie ? 1 : 0,
        size: 13,
        color: Colors.white,
      ),
    );
  }
}

class _AddedBadge extends StatelessWidget {
  const _AddedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
      ),
      child: const Icon(Symbols.check, size: 14, color: AppColors.navy),
    );
  }
}
