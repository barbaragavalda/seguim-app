import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/movies_provider.dart';
import '../widgets/movie_row.dart';

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

    final state = ref.watch(moviesProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.items.isEmpty) {
      return Scaffold(
        body: SafeArea(child: Center(child: Text(l10n.watchlistEmpty))),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(moviesProvider.notifier).load(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                return LoadingMoreIndicator(isLoadingMore: state.isLoadingMore);
              }
              return MovieRow(
                item: state.items[index],
                onReturned: () => ref.read(moviesProvider.notifier).load(),
              );
            },
          ),
        ),
      ),
    );
  }
}
