import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
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
                  header: _SectionHeader(
                    title: l10n.watchlistSectionNotStarted,
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
