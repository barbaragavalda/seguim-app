import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/movie_card.dart';
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
      appBar: AppBar(
        title: Text(l10n.favoriteMoviesRow),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add),
            tooltip: l10n.addFavoriteTitle,
            onPressed: () => context.push('/favorites/movies/add'),
          ),
        ],
      ),
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
      itemBuilder: (context, index) {
        final movie = state.items[index];
        return MovieCard(
          movie: movie,
          l10n: l10n,
          removeTooltip: l10n.removeFromFavoritesAction,
          onRemove: () =>
              ref.read(favoriteMoviesProvider.notifier).remove(movie.tvdbId),
        );
      },
    );
  }
}
