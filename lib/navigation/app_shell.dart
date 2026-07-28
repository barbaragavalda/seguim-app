import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/lists/providers/lists_provider.dart';
import '../features/watchlist/providers/watchlist_provider.dart';
import '../l10n/generated/app_localizations.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _watchlistBranchIndex = 0;
  static const _listsBranchIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // each tab's screen stays alive in the IndexedStack once visited,
          // so its own initState never re-fires - refresh here instead
          // whenever the user switches back to it (e.g. after renaming a
          // list from its detail screen, or adding to the watchlist from a
          // search result)
          if (index == _watchlistBranchIndex) {
            ref.read(watchlistProvider.notifier).load();
          }
          if (index == _listsBranchIndex) {
            ref.read(listsProvider.notifier).load();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: l10n.navWatchlist,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n.navLists,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
