import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../watchlist/widgets/watchlist_item_row.dart';
import '../data/my_series_api.dart';
import '../providers/my_series_provider.dart';

String _statusLabel(AppLocalizations l10n, SeriesStatus status) {
  return switch (status) {
    SeriesStatus.all => l10n.statusAll,
    SeriesStatus.watching => l10n.watchlistSectionWatching,
    SeriesStatus.notStarted => l10n.sectionNotWatchedYet,
    SeriesStatus.finished => l10n.statusFinished,
    SeriesStatus.archived => l10n.statusArchived,
    SeriesStatus.removed => l10n.statusRemoved,
  };
}

class MySeriesScreen extends ConsumerStatefulWidget {
  const MySeriesScreen({super.key});

  @override
  ConsumerState<MySeriesScreen> createState() => _MySeriesScreenState();
}

class _MySeriesScreenState extends ConsumerState<MySeriesScreen> {
  static const _loadMoreThreshold = 300;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as WatchlistScreen/
    // ProfileScreen's initState
    Future.microtask(() => ref.read(mySeriesProvider.notifier).load());
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
      ref.read(mySeriesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(mySeriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySeriesRow)),
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
                          ref.read(mySeriesProvider.notifier).onSearchChanged(value),
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
    MySeriesState state,
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
      return Center(child: Text(l10n.mySeriesEmpty));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return LoadingMoreIndicator(isLoadingMore: state.isLoadingMore);
        }
        return WatchlistItemRow(
          item: state.items[index],
          l10n: l10n,
          onReturned: () => ref.read(mySeriesProvider.notifier).load(),
        );
      },
    );
  }
}

class _StatusSelector extends ConsumerWidget {
  const _StatusSelector({required this.status, required this.l10n});

  final SeriesStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Theme.of(context).dividerColor;

    return PopupMenuButton<SeriesStatus>(
      initialValue: status,
      onSelected: (value) =>
          ref.read(mySeriesProvider.notifier).setStatus(value),
      itemBuilder: (context) => [
        for (final option in SeriesStatus.values)
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
