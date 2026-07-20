import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seguim/main.dart';

void main() {
  testWidgets('shows the Catalan translation when the locale is ca', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SeguimApp(locale: Locale('ca'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Watchlist'), findsWidgets);
    expect(find.text('Inicia sessió per veure la teva watchlist'), findsOneWidget);
  });

  testWidgets('shows the English translation when the locale is en', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SeguimApp(locale: Locale('en'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in to see your watchlist'), findsOneWidget);
  });

  testWidgets('shows the Spanish translation when the locale is es', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SeguimApp(locale: Locale('es'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión para ver tu watchlist'), findsOneWidget);
  });
}
