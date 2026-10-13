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
/// Root cause (fixed in lib/): GoRouter was recreated on every auth state
/// change (goRouterProvider watched authStateProvider). When SplashScreen's
/// timer fired initializeAuth(), the `isLoading: true` state change rebuilt
/// the router, disposed the SplashScreen, and the `!mounted` guard blocked
/// navigation forever — an infinite splash loop. Fixed via
/// AuthRefreshNotifier + refreshListenable (router created once).
///
/// Timing notes: the test avoids pumpAndSettle() (which waits indefinitely
/// for animations/frames) and instead pumps in bounded steps, polling for
/// the expected screen. A 30s timeout converts any hang into a failure
/// with diagnostics instead of an indefinite stall.
void main() {
  testWidgets(
    'splash navigates to login after initialization',
    (WidgetTester tester) async {
      print('[TEST] phase 1: creating temp dir');
      final tempDir =
          await Directory.systemTemp.createTemp('quickbite_test');

      print('[TEST] phase 2: Hive.init');
      Hive.init(tempDir.path);

      print('[TEST] phase 3: opening Hive boxes');
      final storage = LocalStorageService();
      await storage.init();
      print('[TEST] phase 3 done: boxes open');

      print('[TEST] phase 4: pumpWidget');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
          ],
          child: const QuickBiteApp(),
        ),
      );
      print('[TEST] phase 4 done: app pumped');

      // Splash screen is showing initially.
      expect(find.byType(SplashScreen), findsOneWidget);
      print('[TEST] phase 5: splash visible, advancing timer');

      // Advance past the 1400ms splash timer in bounded steps, polling
      // for navigation. Never waits indefinitely.
      bool navigated = false;
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LoginScreen).evaluate().isNotEmpty) {
          navigated = true;
          print('[TEST] phase 5 done: navigated to login at step $i');
          break;
        }
      }

      // Must navigate to login (not stuck on splash).
      expect(navigated, isTrue,
          reason: 'Timed out waiting for navigation to LoginScreen');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      print('[TEST] phase 6: cleanup');
      await Hive.close();
      await tempDir.delete(recursive: true);
      print('[TEST] done: PASS');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
