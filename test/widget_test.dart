import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seguim/main.dart';

void main() {
  testWidgets('HomePage shows welcome text', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SeguimApp()));

    expect(find.text('Benvingut a Seguim'), findsOneWidget);
  });
}
