import 'package:go_router/go_router.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/import/data/pending_entry.dart';
import '../features/import/screens/pending_resolution_screen.dart';
import '../features/import/screens/tvtime_import_screen.dart';
import '../features/lists/screens/list_detail_screen.dart';
import '../features/lists/screens/lists_screen.dart';
import '../features/movie_detail/screens/movie_detail_screen.dart';
import '../features/movies/screens/movies_screen.dart';
import '../features/my_movies/screens/my_movies_screen.dart';
import '../features/my_series/screens/my_series_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/series_detail/screens/series_detail_screen.dart';
import '../features/watchlist/screens/watchlist_screen.dart';
import 'app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/watchlist',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/series/:tvdbId',
      builder: (context, state) =>
          SeriesDetailScreen(tvdbId: state.pathParameters['tvdbId']!),
    ),
    GoRoute(
      path: '/movies/:tvdbId',
      builder: (context, state) =>
          MovieDetailScreen(tvdbId: state.pathParameters['tvdbId']!),
    ),
    GoRoute(
      path: '/import/tvtime',
      builder: (context, state) => const TvTimeImportScreen(),
    ),
    GoRoute(
      path: '/import/pending',
      builder: (context, state) => const PendingResolutionScreen(),
    ),
    GoRoute(
      path: '/import/pending/resolve',
      builder: (context, state) =>
          SearchScreen(resolveEntry: state.extra as PendingEntry),
    ),
    GoRoute(
      path: '/my-series',
      builder: (context, state) => const MySeriesScreen(),
    ),
    GoRoute(
      path: '/my-movies',
      builder: (context, state) => const MyMoviesScreen(),
    ),
    GoRoute(
      path: '/lists/:id',
      builder: (context, state) => ListDetailScreen(
        listId: int.parse(state.pathParameters['id']!),
        name: (state.extra as String?) ?? '',
      ),
    ),
    GoRoute(
      path: '/lists/:id/add',
      builder: (context, state) =>
          SearchScreen(addToListId: int.parse(state.pathParameters['id']!)),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/watchlist',
              builder: (context, state) => const WatchlistScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/movies',
              builder: (context, state) => const MoviesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/lists',
              builder: (context, state) => const ListsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
