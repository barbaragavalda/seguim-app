import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/watchlist_provider.dart';
import '../widgets/watchlist_item_row.dart';

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
    final hasData = state.watching.isNotEmpty || state.notStarted.isNotEmpty;

    // only the very first load (nothing to show yet) blocks the screen with
    // a spinner - a later reload (WatchlistItemRow's own onReturned after
    // coming back from a series/movie detail screen, or a manual pull-to-
    // refresh) keeps the existing CustomScrollView on screen instead of
    // tearing it down and rebuilding it, which would otherwise reset its
    // own scroll position back to the top every time
    if (state.isLoading && !hasData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!hasData) {
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
                  header: SectionHeader(title: l10n.watchlistSectionWatching),
                  sliver: SliverList.builder(
                    itemCount: state.watching.length,
                    itemBuilder: (context, index) => WatchlistItemRow(
                      item: state.watching[index],
                      l10n: l10n,
                      onReturned: () =>
                          ref.read(watchlistProvider.notifier).load(),
                    ),
                  ),
                ),
              if (state.notStarted.isNotEmpty)
                SliverStickyHeader(
                  header: SectionHeader(
                    title: l10n.sectionNotWatchedYet,
                  ),
                  sliver: SliverList.builder(
                    itemCount:
                        state.notStarted.length +
                        (state.notStartedHasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.notStarted.length) {
                        return LoadingMoreIndicator(
                          isLoadingMore: state.isLoadingMore,
                        );
                      }
                      return WatchlistItemRow(
                        item: state.notStarted[index],
                        l10n: l10n,
                        onReturned: () =>
                            ref.read(watchlistProvider.notifier).load(),
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
