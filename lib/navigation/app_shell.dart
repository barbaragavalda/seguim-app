import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/favorites/providers/favorites_summary_provider.dart';
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
    // TV Time import (the only source of pending titles) is web-only
    if (kIsWeb) {
      Future.microtask(() {
        ref.read(pendingCountProvider.notifier).load();
        // covers the case where authProvider is already restored by now;
        // otherwise a no-op, and build()'s ref.listen catches the restore
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

    // AppShell is mounted once for the whole tab-bar lifetime, so re-load on
    // login from elsewhere. Also the reliable path for resumeIfInProgress():
    // authProvider restores its token from secure storage asynchronously, so
    // it's still null when initState()'s microtask runs above; this
    // login-transition catches it once the restore actually finishes.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && previous?.isLoggedIn != true) {
        ref.read(pendingCountProvider.notifier).load();
        ref.read(tvTimeImportProvider.notifier).resumeIfInProgress();
      }
    });

    // resolving is blocked while importing, so refresh the count exactly
    // once import finishes rather than poll while it's pointless
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
          // each tab stays alive in the IndexedStack, so initState never
          // re-fires - refresh explicitly on switching back to it
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
            ref.read(favoritesSummaryProvider.notifier).load();
          }
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        // Material Symbols' fill is a variable-font axis, so selected state
        // is just fill: 0 vs 1 of the same icon, not separate icon names
        destinations: [
          NavigationDestination(
            icon: const Icon(Symbols.tv, fill: 0),
            selectedIcon: const Icon(Symbols.tv, fill: 1),
            label: l10n.navWatchlist,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.local_activity, fill: 0),
            selectedIcon: const Icon(Symbols.local_activity, fill: 1),
            label: l10n.navMovies,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.pageview, fill: 0),
            selectedIcon: const Icon(Symbols.pageview, fill: 1),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.list_alt, fill: 0),
            selectedIcon: const Icon(Symbols.list_alt, fill: 1),
            label: l10n.navLists,
          ),
          NavigationDestination(
            icon: _ProfileIcon(
              fill: 0,
              // 0 while importing - resolving is blocked then anyway
              badgeCount: importing ? 0 : pendingMoviesCount,
            ),
            selectedIcon: _ProfileIcon(
              fill: 1,
              badgeCount: importing ? 0 : pendingMoviesCount,
            ),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}

/// The "Perfil" tab's icon with a badge for pending titles to resolve.
class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({required this.fill, required this.badgeCount});

  final double fill;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text('$badgeCount'),
      isLabelVisible: badgeCount > 0,
      child: Icon(Symbols.person, fill: fill),
    );
  }
}
