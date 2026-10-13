import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:quickbite/main.dart';
import 'package:quickbite/screens/splash_screen.dart';
import 'package:quickbite/screens/login_screen.dart';
import 'package:quickbite/services/local_storage.dart';

/// Regression test for the Web splash-screen hang.
///
/// Root cause (fixed): GoRouter was recreated on every auth state change
/// (goRouterProvider watched authStateProvider). When SplashScreen's timer
/// fired initializeAuth(), the `isLoading: true` state change rebuilt the
/// router, disposed the SplashScreen, and the `!mounted` guard blocked
/// navigation forever — an infinite splash loop.
///
/// This test pumps the app with initialized Hive boxes, advances past the
/// splash timer, and asserts the app navigates to LoginScreen instead of
/// getting stuck on SplashScreen.
void main() {
  testWidgets('splash navigates to login after initialization',
      (WidgetTester tester) async {
    // Initialize Hive with a temp directory (no Flutter bindings needed).
    final tempDir =
        await Directory.systemTemp.createTemp('quickbite_test');
    Hive.init(tempDir.path);
    final storage = LocalStorageService();
    await storage.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const QuickBiteApp(),
      ),
    );

    // Splash screen is showing initially.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance past the 1400ms splash timer and let navigation settle.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Must navigate to login (not stuck on splash).
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    await Hive.close();
    await tempDir.delete(recursive: true);
  });
}
