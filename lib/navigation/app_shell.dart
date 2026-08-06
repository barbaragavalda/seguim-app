import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/import/providers/pending_count_provider.dart';
import '../features/import/providers/tvtime_import_provider.dart';
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
  static const _profileBranchIndex = 4;

  @override
  void initState() {
    super.initState();
    // web-only - see _ImportSection's own docblock on why the whole TV Time
    // import feature (the only source of pending titles) is web-only, so
    // fetching this count elsewhere would never find anything
    if (kIsWeb) {
      Future.microtask(() {
        ref.read(pendingCountProvider.notifier).load();
        // covers the case where authProvider is *already* restored by the
        // time this runs (see the ref.listen in build() for the more
        // common case, where it's still mid-restore right now) -
        // resumeIfInProgress() itself is a no-op without a token, so this
        // is harmless if it isn't ready yet
        ref.read(tvTimeImportProvider.notifier).resumeIfInProgress();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pendingMoviesCount = ref.watch(pendingCountProvider);
    final importing =
        ref.watch(tvTimeImportProvider.select((s) => s.phase)) ==
        TvTimeImportPhase.processing;

    // AppShell is mounted once for the whole logged-in/out lifetime of the
    // tab bar - re-load when the user logs in from elsewhere (e.g. the
    // Perfil tab itself), same reasoning as WatchlistScreen/MoviesScreen's
    // own auth listeners. Also the *reliable* path for resumeIfInProgress()
    // right after a fresh app start/restart: authProvider restores its
    // token from secure storage asynchronously (AuthController.
    // _restoreSession()), so it's still null at the exact moment
    // initState()'s own microtask runs above - that call is a harmless
    // no-op then, and this transition (previous token null -> now present)
    // is what actually catches it once the restore finishes. Confirmed
    // happening for real: a job stuck at 'processing' only resumed once the
    // user happened to revisit the import screen, whose own initState
    // re-tries the same check - by then the restore had long since finished
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(pendingCountProvider.notifier).load();
        ref.read(tvTimeImportProvider.notifier).resumeIfInProgress();
      }
    });

    // resolving is blocked while importing (PendingResolutionScreen and the
    // Perfil row both refuse to act on this count then - see their own
    // docblocks), so there's nothing to gain polling while `importing` is
    // true either: a fresh count is only useful once the user can actually
    // do something with it. This fires exactly once, right as `importing`
    // flips back off, to catch whatever the import's last batch added -
    // without it the badge would stay at its pre-import value until the
    // user happened to reselect the Perfil tab
    ref.listen<TvTimeImportPhase>(
      tvTimeImportProvider.select((s) => s.phase),
      (previous, next) {
        if (previous == TvTimeImportPhase.processing &&
            next != TvTimeImportPhase.processing) {
          ref.read(pendingCountProvider.notifier).load();
        }
      },
    );

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
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
          if (index == _profileBranchIndex) {
            ref.read(pendingCountProvider.notifier).load();
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
              // 0 (not the real count) while importing - resolving is
              // blocked then anyway, see _PendingResolutionAccountRow's own
              // docblock
              badgeCount: importing ? 0 : pendingMoviesCount,
            ),
            selectedIcon: _ProfileIcon(
              icon: Icons.person,
              badgeCount: importing ? 0 : pendingMoviesCount,
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
