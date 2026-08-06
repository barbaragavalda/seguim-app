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
  // Fraunces/Manrope are bundled locally under assets/fonts/google_fonts/
  // (see pubspec.yaml) instead of relying on google_fonts' default
  // runtime-fetch-from-fonts.gstatic.com behavior - that CDN call kept
  // failing in the wild (blocked by ad/privacy blockers, or plain network
  // hiccups), silently breaking the app's typography. Disallowing runtime
  // fetching makes a missing bundled variant a loud, obvious error instead
  // of an intermittent network-dependent one.
  GoogleFonts.config.allowRuntimeFetching = false;

  // A plain ProviderContainer (rather than just ProviderScope) so
  // decodeApiResponse - a top-level function outside the widget tree, called
  // from every *_api.dart file - can still reach authProvider when any
  // request comes back 401 (deleted/invalidated user - see checkToken()'s
  // own docblock on the backend). UncontrolledProviderScope makes the widget
  // tree use this same container instead of creating its own.
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
