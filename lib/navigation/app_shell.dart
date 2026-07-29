import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/import/providers/pending_resolution_provider.dart';
import '../features/lists/providers/lists_provider.dart';
import '../features/movies/providers/movies_provider.dart';
import '../features/watchlist/providers/watchlist_provider.dart';
import '../l10n/generated/app_localizations.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _watchlistBranchIndex = 0;
  static const _moviesBranchIndex = 1;
  static const _listsBranchIndex = 3;

  @override
  void initState() {
    super.initState();
    // loaded here (rather than only from ProfileScreen/PendingResolutionScreen)
    // so the "Perfil" tab's badge already has a real count the moment the
    // app opens, not just once the user actually visits one of those
    // screens - same "modify provider outside build" reasoning as every
    // other screen's initState in this app
    Future.microtask(() => ref.read(pendingResolutionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pendingMoviesCount = ref.watch(
      pendingResolutionProvider.select((s) => s.items.length),
    );

    // AppShell is mounted once for the whole logged-in/out lifetime of the
    // tab bar - re-load when the user logs in from elsewhere (e.g. the
    // Perfil tab itself), same reasoning as WatchlistScreen/MoviesScreen's
    // own auth listeners
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(pendingResolutionProvider.notifier).load();
      }
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // each tab's screen stays alive in the IndexedStack once visited,
          // so its own initState never re-fires - refresh here instead
          // whenever the user switches back to it (e.g. after renaming a
          // list from its detail screen, or adding to the watchlist from a
          // search result)
          if (index == _watchlistBranchIndex) {
            ref.read(watchlistProvider.notifier).load();
          }
          if (index == _moviesBranchIndex) {
            ref.read(moviesProvider.notifier).load();
          }
          if (index == _listsBranchIndex) {
            ref.read(listsProvider.notifier).load();
          }
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.tv_outlined),
            selectedIcon: const Icon(Icons.tv),
            label: l10n.navWatchlist,
          ),
          NavigationDestination(
            icon: const Icon(Icons.videocam_outlined),
            selectedIcon: const Icon(Icons.videocam),
            label: l10n.navMovies,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_outlined),
            selectedIcon: const Icon(Icons.list),
            label: l10n.navLists,
          ),
          NavigationDestination(
            icon: _ProfileIcon(
              icon: Icons.person_outline,
              badgeCount: pendingMoviesCount,
            ),
            selectedIcon: _ProfileIcon(
              icon: Icons.person,
              badgeCount: pendingMoviesCount,
            ),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

/// The "Perfil" tab's icon, with a small badge when there's something
/// waiting for the user there - currently pending series/movie titles to
/// resolve (Api\Model\SeriesImportPending/MovieImportPending), but written
/// generically enough to fold in other "needs attention" counts later if
/// any show up.
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('$badgeCount'),
      isLabelVisible: badgeCount > 0,
      child: Icon(icon),
    );
  }
}
