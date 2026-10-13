import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickbite/main.dart';
import 'package:quickbite/screens/splash_screen.dart';
import 'package:quickbite/screens/login_screen.dart';
import 'package:quickbite/services/local_storage.dart';

/// In-memory fake of LocalStorageService — no Hive boxes, no filesystem.
///
/// The previous version used real Hive boxes under Directory.systemTemp,
/// but `Directory.systemTemp.createTemp()` hangs indefinitely in this
/// Flutter test environment (macOS), stalling the test before phase 2.
/// Since this regression test verifies splash -> login NAVIGATION (the
/// GoRouter refreshListenable fix), not Hive I/O itself, an in-memory
/// fake is the correct, deterministic harness. The production Hive
/// initialization path (main() -> LocalStorageService.init()) is
/// exercised on device, not in widget tests.
class FakeLocalStorageService extends LocalStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> init() async {
    // No-op: no Hive boxes to open.
  }

  @override
  Future<void> saveToken(String token) async {
    _store['token'] = token;
  }

  @override
  String? getToken() => _store['token'];

  @override
  Future<void> deleteToken() async {
    _store.remove('token');
  }

  @override
  Future<void> saveUser(String userJson) async {
    _store['user'] = userJson;
  }

  @override
  String? getUser() => _store['user'];

  @override
  Future<void> deleteUser() async {
    _store.remove('user');
  }

  @override
  Future<void> saveOrders(String ordersJson) async {
    _store['orders'] = ordersJson;
  }

  @override
  String? getOrders() => _store['orders'];

  @override
  Future<void> deleteOrders() async {
    _store.remove('orders');
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

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
      print('[TEST] phase 1: creating in-memory storage (no filesystem)');
      final storage = FakeLocalStorageService();
      await storage.init();
      print('[TEST] phase 1 done: storage ready');

      print('[TEST] phase 2: pumpWidget');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
          ],
          child: const QuickBiteApp(),
        ),
      );
      print('[TEST] phase 2 done: app pumped');

      // Splash screen is showing initially.
      expect(find.byType(SplashScreen), findsOneWidget);
      print('[TEST] phase 3: splash visible, advancing timer');

      // Advance past the 1400ms splash timer in bounded steps, polling
      // for navigation. Never waits indefinitely.
      //
      // Note: when GoRouter navigates splash -> login, the outgoing
      // SplashScreen stays in the widget tree until the MaterialPage
      // transition (~300ms) completes. So we wait for BOTH: LoginScreen
      // present AND SplashScreen removed. Finding LoginScreen alone only
      // proves navigation started, not that splash is gone.
      bool navigated = false;
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final loginFound =
            find.byType(LoginScreen).evaluate().isNotEmpty;
        final splashGone =
            find.byType(SplashScreen).evaluate().isEmpty;
        if (loginFound && splashGone) {
          navigated = true;
          print('[TEST] phase 3 done: login shown, splash removed '
              'at step $i');
          break;
        }
        if (loginFound && !splashGone && i % 5 == 0) {
          print('[TEST] phase 3: login visible at step $i, '
              'waiting for splash transition to finish...');
        }
      }

      // Must navigate to login (not stuck on splash).
      expect(navigated, isTrue,
          reason: 'Timed out waiting for splash -> login transition '
              'to complete');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      print('[TEST] done: PASS');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
