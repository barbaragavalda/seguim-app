import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/app_intro.dart';
import '../../../widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/movies_provider.dart';
import '../widgets/movie_grid_card.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  final _scrollController = ScrollController();

  static const _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    // same "modify provider outside build" reasoning as WatchlistScreen's
    // initState
    Future.microtask(() => ref.read(moviesProvider.notifier).load());
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
      ref.read(moviesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    // reload once the user logs in from elsewhere while this tab stays
    // mounted - same reasoning as WatchlistScreen's own listener
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(moviesProvider.notifier).load();
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
                  const AppIntro(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.moviesLoginPrompt, textAlign: TextAlign.center),
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

    final state = ref.watch(moviesProvider);
    final hasData = state.items.isNotEmpty;

    // see WatchlistScreen's own comment on the identical guard - only the
    // very first load blocks the screen with a spinner, so a later reload
    // (MovieGridCard's own onReturned, or pull-to-refresh) doesn't tear
    // down and rebuild the CustomScrollView, which would otherwise reset
    // its scroll position back to the top every time
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
          onRefresh: () => ref.read(moviesProvider.notifier).load(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverStickyHeader(
                header: SectionHeader(title: l10n.sectionNotWatchedYet),
                // same poster-grid delegate as MyMoviesScreen's own grid;
                // status label (e.g. "Estrenada"/"Pròximament") still shows
                // under each poster - useful since a not-yet-released movie
                // can already sit in the watchlist.
                sliver: SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.5,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => MovieGridCard(
                        movie: state.items[index],
                        l10n: l10n,
                        onReturned: () =>
                            ref.read(moviesProvider.notifier).load(),
                      ),
                      childCount: state.items.length,
                    ),
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
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ],
          ),
        ),
      ),
    );
  }
}
