import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/restaurant_detail_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/order_confirmation_screen.dart';
import '../screens/order_tracking_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/admin_screen.dart';
import '../widgets/qb_shell.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

/// Notifies GoRouter when auth state changes WITHOUT recreating the router.
///
/// Previously the GoRouter was rebuilt on every auth state change, which reset
/// navigation to /splash and disposed the SplashScreen mid-initialization —
/// the `!mounted` guard then blocked navigation forever (infinite splash loop).
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    // Re-evaluate `redirect` on auth changes; the router instance itself
    // is created once and never reset.
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // Read (not watch): refreshListenable already triggers re-evaluation.
      final authState = ref.read(authStateProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.token != null;

      // Splash screen takes priority
      if (state.fullPath == '/splash') {
        return null;
      }

      // Redirect to login if not authenticated
      if (!isLoading && !isLoggedIn && state.fullPath != '/login') {
        return '/login';
      }

      // Redirect to home if authenticated and trying to access login
      if (!isLoading && isLoggedIn && state.fullPath == '/login') {
        return '/';
      }

      // Admin route protection: non-admins are sent home.
      // The backend also enforces this (require_admin -> 403).
      if (!isLoading &&
          isLoggedIn &&
          state.fullPath == '/admin' &&
          authState.user?.role != UserRole.admin) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Tab screens wrapped in the responsive shell (sidebar / bottom nav).
      ShellRoute(
        builder: (context, state, child) =>
            QbShell(location: state.uri.toString(), child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/orders',
            name: 'order-history',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/restaurant/:id',
        name: 'restaurant-detail',
        builder: (context, state) {
          final restaurantId = state.pathParameters['id']!;
          return RestaurantDetailScreen(restaurantId: restaurantId);
        },
      ),
      GoRoute(
        path: '/cart',
        name: 'cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order/:id/confirmation',
        name: 'order-confirmation',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderConfirmationScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/order/:id/tracking',
        name: 'order-tracking',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
  );
});
