import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../movies/data/movies_api.dart' show MovieStatus;
import '../../movies/widgets/movie_grid_card.dart';
import '../providers/my_movies_provider.dart';

String _statusLabel(AppLocalizations l10n, MovieStatus status) {
  return switch (status) {
    MovieStatus.all => l10n.statusAll,
    MovieStatus.notWatched => l10n.statusNotWatched,
    MovieStatus.watched => l10n.statusWatched,
  };
}

class MyMoviesScreen extends ConsumerStatefulWidget {
  const MyMoviesScreen({super.key});

  @override
  ConsumerState<MyMoviesScreen> createState() => _MyMoviesScreenState();
}

class _MyMoviesScreenState extends ConsumerState<MyMoviesScreen> {
  static const _loadMoreThreshold = 300;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as MySeriesScreen's
    // initState
    Future.microtask(() => ref.read(myMoviesProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(myMoviesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(myMoviesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myMoviesRow)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          ref.read(myMoviesProvider.notifier).onSearchChanged(value),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: l10n.mySeriesSearchPlaceholder,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StatusSelector(status: state.status, l10n: l10n),
                ],
              ),
            ),
            Expanded(child: _buildBody(context, l10n, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    MyMoviesState state,
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
      return Center(child: Text(l10n.myMoviesEmpty));
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
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
              (context, index) => MovieGridCard(movie: state.items[index], l10n: l10n),
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
    );
  }
}


class _StatusSelector extends ConsumerWidget {
  const _StatusSelector({required this.status, required this.l10n});

  final MovieStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Theme.of(context).dividerColor;

    return PopupMenuButton<MovieStatus>(
      initialValue: status,
      onSelected: (value) =>
          ref.read(myMoviesProvider.notifier).setStatus(value),
      itemBuilder: (context) => [
        for (final option in MovieStatus.values)
          PopupMenuItem(value: option, child: Text(_statusLabel(l10n, option))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: dividerColor),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _statusLabel(l10n, status),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
