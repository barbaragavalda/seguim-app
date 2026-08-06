import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/series_poster.dart';
import '../../../widgets/status_tag.dart';
import '../../search/data/series.dart';
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
      appBar: AppBar(title: Text(l10n.favoriteSeriesRow)),
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
      itemBuilder: (context, index) =>
          _SeriesCard(series: state.items[index], l10n: l10n),
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
              SeriesPoster(
                imageUrl: series.imageUrl,
                watchProgress: series.watchProgress,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _RemoveButton(
                  tooltip: l10n.removeFromFavoritesAction,
                  onTap: () => ref
                      .read(favoriteSeriesProvider.notifier)
                      .remove(series.tvdbId),
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
