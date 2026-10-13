// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickbite/main.dart';

void main() {
  testWidgets('QuickBite app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame, wrapped in ProviderScope for Riverpod.
    await tester.pumpWidget(
      const ProviderScope(
        child: QuickBiteApp(),
      ),
    );

    // Verify that the app starts without errors.
    // More comprehensive tests would verify login flow, navigation, etc.
    expect(find.byType(QuickBiteApp), findsOneWidget);

    // Pump for 1.5+ seconds to allow the splash screen's 1.4-second
    // initialization timer and navigation to complete.
    await tester.pump(const Duration(milliseconds: 1500));
  });
}


