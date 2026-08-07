import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/locale/locale_provider.dart';
import 'core/network/api_response_parser.dart';
import 'features/auth/providers/auth_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  // Fonts are bundled locally rather than fetched at runtime from
  // fonts.gstatic.com - that CDN call was failing in the wild (ad/privacy
  // blockers, network hiccups), silently breaking typography. This makes a
  // missing bundled variant a loud error instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  // A plain ProviderContainer (rather than just ProviderScope) so
  // decodeApiResponse - a top-level function outside the widget tree - can
  // still reach authProvider to log out on a 401. UncontrolledProviderScope
  // makes the widget tree use this same container instead of its own.
  final container = ProviderContainer();
  onAuthExpired = () => container.read(authProvider.notifier).logOut();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SeguimApp(),
    ),
  );
}

class SeguimApp extends ConsumerWidget {
  const SeguimApp({super.key, this.locale});

  /// Overrides the locale picked up from [localeProvider] - used by
  /// widget_test.dart to pin a specific locale for each test.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Seguim',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: locale ?? ref.watch(localeProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
