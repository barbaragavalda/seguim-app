import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/series_card.dart';
import '../providers/favorite_series_provider.dart';

/// "Sèries favorites" - reached from ProfileScreen's own preview row.
/// Deliberately not a real Api\Model\UserList (see SerieFavorite's own
/// docblock), so unlike ListDetailScreen this has no rename/add/reorder -
/// just the poster grid and a way to un-favorite one.
class FavoriteSeriesScreen extends ConsumerStatefulWidget {
  const FavoriteSeriesScreen({super.key});

  @override
  ConsumerState<FavoriteSeriesScreen> createState() =>
      _FavoriteSeriesScreenState();
}

class _FavoriteSeriesScreenState extends ConsumerState<FavoriteSeriesScreen> {
  static const _loadMoreThreshold = 300;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as every other
    // screen's initState in this app
    Future.microtask(() => ref.read(favoriteSeriesProvider.notifier).load());
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
      ref.read(favoriteSeriesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(favoriteSeriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favoriteSeriesRow),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add),
            tooltip: l10n.addFavoriteTitle,
            onPressed: () => context.push('/favorites/series/add'),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, l10n, state)),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    FavoriteSeriesState state,
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
      return Center(child: Text(l10n.favoriteSeriesEmpty));
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
        final series = state.items[index];
        return SeriesCard(
          series: series,
          l10n: l10n,
          removeTooltip: l10n.removeFromFavoritesAction,
          onRemove: () =>
              ref.read(favoriteSeriesProvider.notifier).remove(series.tvdbId),
        );
      },
    );
  }
}
