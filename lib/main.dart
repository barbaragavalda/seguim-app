import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SeguimApp()));
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
