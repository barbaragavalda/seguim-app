import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seguim/main.dart';

void main() {
  testWidgets('starts on the Watchlist tab with a logged-out prompt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: SeguimApp()));
    await tester.pumpAndSettle();

    expect(find.text('Watchlist'), findsWidgets);
    expect(find.text('Inicia sessió per veure la teva watchlist'), findsOneWidget);
  });
}
