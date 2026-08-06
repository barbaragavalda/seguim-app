import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../lists/data/list_movie.dart';
import '../providers/favorite_movies_provider.dart';

/// "Pel·lícules favorites" - mirrors FavoriteSeriesScreen exactly, own
/// docblock has the full reasoning.
class FavoriteMoviesScreen extends ConsumerStatefulWidget {
  const FavoriteMoviesScreen({super.key});

  @override
  ConsumerState<FavoriteMoviesScreen> createState() =>
      _FavoriteMoviesScreenState();
}

class _FavoriteMoviesScreenState extends ConsumerState<FavoriteMoviesScreen> {
  static const _loadMoreThreshold = 300;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(favoriteMoviesProvider.notifier).load());
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
      ref.read(favoriteMoviesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(favoriteMoviesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoriteMoviesRow)),
      body: SafeArea(child: _buildBody(context, l10n, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    FavoriteMoviesState state,
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
      return Center(child: Text(l10n.favoriteMoviesEmpty));
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.5,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) =>
          _MovieCard(movie: state.items[index], l10n: l10n),
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
                  tooltip: l10n.removeFromFavoritesAction,
                  onTap: () => ref
                      .read(favoriteMoviesProvider.notifier)
                      .remove(movie.tvdbId),
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

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }
}
