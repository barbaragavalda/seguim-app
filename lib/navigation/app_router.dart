import 'package:go_router/go_router.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/import/screens/tvtime_import_screen.dart';
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
      path: '/import/tvtime',
      builder: (context, state) => const TvTimeImportScreen(),
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
              path: '/search',
              builder: (context, state) => const SearchScreen(),
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
