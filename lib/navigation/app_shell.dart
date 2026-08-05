import 'dart:async';

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

  // AppShell is mounted for the whole logged-in/out lifetime of the tab bar,
  // so it - not ProfileScreen - is what keeps this badge live: an import
  // running in the background keeps adding pending titles the whole time,
  // not just while the user happens to be looking at the Perfil tab. Own
  // provider (pendingCountProvider), not pendingResolutionProvider - see
  // that provider's own docblock on why: this poll must never be the one
  // that reloads PendingResolutionScreen's full item list, or a poll firing
  // while the user has candidates ticked there would wipe them out.
  //
  // Two speeds, not one fixed tick - polling every 5s forever, even with
  // nothing pending and no import running (the overwhelmingly common case),
  // was pure waste. _activeInterval only applies while there's an actual
  // reason to expect the count to change soon (something already pending,
  // or an import that could add more); otherwise _idleInterval is just an
  // occasional heartbeat, mainly to notice an import started from another
  // device/tab. _currentInterval tracks which one the running timer was
  // last (re)created with, so build() only ever restarts it on an actual
  // active/idle transition, not on every unrelated rebuild.
  static const _activeInterval = Duration(seconds: 5);
  static const _idleInterval = Duration(minutes: 2);

  Timer? _pendingCountPollTimer;
  Duration? _currentInterval;

  @override
  void initState() {
    super.initState();
    // web-only - see _ImportSection's own docblock on why the whole TV Time
    // import feature (the only source of pending titles) is web-only, so
    // polling for this count elsewhere would never find anything
    if (kIsWeb) {
      Future.microtask(() => ref.read(pendingCountProvider.notifier).load());
    }
  }

  void _setPollInterval(Duration interval) {
    if (_currentInterval == interval) return;
    _currentInterval = interval;
    _pendingCountPollTimer?.cancel();
    _pendingCountPollTimer = Timer.periodic(
      interval,
      (_) => ref.read(pendingCountProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _pendingCountPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pendingMoviesCount = ref.watch(pendingCountProvider);
    final importing =
        ref.watch(tvTimeImportProvider.select((s) => s.phase)) ==
        TvTimeImportPhase.processing;

    if (kIsWeb) {
      _setPollInterval(
        pendingMoviesCount > 0 || importing
            ? _activeInterval
            : _idleInterval,
      );
    }

    // AppShell is mounted once for the whole logged-in/out lifetime of the
    // tab bar - re-load when the user logs in from elsewhere (e.g. the
    // Perfil tab itself), same reasoning as WatchlistScreen/MoviesScreen's
    // own auth listeners
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(pendingCountProvider.notifier).load();
      }
    });

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
