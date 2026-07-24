import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radius.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/placeholder_mark.dart';
import '../../../widgets/status_tag.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/watchlist_item.dart';
import '../providers/watchlist_provider.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final _scrollController = ScrollController();

  static const _loadMoreThreshold = 200;

  @override
  void initState() {
    super.initState();
    // Riverpod forbids modifying provider state synchronously during a
    // widget lifecycle method - defer to the next microtask (see the
    // equivalent comment on SeriesDetailScreen.initState).
    Future.microtask(() => ref.read(watchlistProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(watchlistProvider.notifier).loadMoreNotStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    // reload once the user logs in from elsewhere while this tab stays
    // mounted (StatefulShellRoute keeps every tab alive) - initState only
    // ever fires once, so it can't catch a later login on its own
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(watchlistProvider.notifier).load();
      }
    });

    if (!isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.watchlistLoginPrompt, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context.push('/login'),
                    child: Text(l10n.logIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(watchlistProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.watching.isEmpty && state.notStarted.isEmpty) {
      return Scaffold(
        body: SafeArea(child: Center(child: Text(l10n.watchlistEmpty))),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(watchlistProvider.notifier).load(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              if (state.watching.isNotEmpty)
                SliverStickyHeader(
                  header: _SectionHeader(title: l10n.watchlistSectionWatching),
                  sliver: SliverList.builder(
                    itemCount: state.watching.length,
                    itemBuilder: (context, index) => _WatchlistItemRow(
                      item: state.watching[index],
                      l10n: l10n,
                    ),
                  ),
                ),
              if (state.notStarted.isNotEmpty)
                SliverStickyHeader(
                  header: _SectionHeader(
                    title: l10n.watchlistSectionNotStarted,
                  ),
                  sliver: SliverList.builder(
                    itemCount:
                        state.notStarted.length +
                        (state.notStartedHasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.notStarted.length) {
                        return const _LoadingMoreIndicator();
                      }
                      return _WatchlistItemRow(
                        item: state.notStarted[index],
                        l10n: l10n,
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.md),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  static const double _height = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // frosted, floating section header (like iOS grouped lists): content
    // scrolls under a blurred, translucent bar rather than a solid one
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: _height,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withValues(alpha: 0.78),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(
            title,
            style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _WatchlistItemRow extends ConsumerWidget {
  const _WatchlistItemRow({required this.item, required this.l10n});

  final WatchlistItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Theme.of(context).dividerColor;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    return GestureDetector(
      onTap: () async {
        // the series detail screen may change watched/watchlist state (mark
        // an episode watched, remove from watchlist) - refresh once the
        // user comes back rather than showing stale counts
        await context.push('/series/${item.tvdbId}');
        if (context.mounted) {
          ref.read(watchlistProvider.notifier).load();
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: dividerColor),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 108,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.imageUrl == null
                      ? const PlaceholderMark(fontSize: 15)
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (context, url) =>
                              const PlaceholderMark(fontSize: 15),
                          errorWidget: (context, url, error) =>
                              const PlaceholderMark(fontSize: 15),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.episodeCode != null)
                    Text.rich(
                      TextSpan(
                        style: bodySmall,
                        children: [
                          TextSpan(text: '${l10n.nextEpisodeLabel} '),
                          TextSpan(
                            text: item.episodeCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          TextSpan(text: ' · ${item.nextEpisodeName ?? ''}'),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusTag(
                          label: l10n.premiereUpcoming,
                          color: seriesStatusColor('Upcoming'),
                        ),
                        if (item.premiereInDays != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.premiereInDays(item.premiereInDays!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (item.remainingEpisodes > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.episodesRemaining(item.remainingEpisodes),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMoreIndicator extends ConsumerWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingMore = ref.watch(
      watchlistProvider.select((s) => s.isLoadingMore),
    );
    if (!isLoadingMore) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
