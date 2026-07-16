// Basic smoke test for the RRS app

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:r2p_app/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    // Build the app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RRSApp(),
      ),
    );

    // Verify that the splash screen shows the app name
    expect(find.text('Indian Railways'), findsOneWidget);
    expect(find.text('Rapid Response System'), findsOneWidget);
  });
}
