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
import '../providers/auth_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
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
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'restaurant/:id',
            name: 'restaurant-detail',
            builder: (context, state) {
              final restaurantId = state.pathParameters['id']!;
              return RestaurantDetailScreen(restaurantId: restaurantId);
            },
          ),
          GoRoute(
            path: 'cart',
            name: 'cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: 'checkout',
            name: 'checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: 'order/:id/confirmation',
            name: 'order-confirmation',
            builder: (context, state) {
              final orderId = state.pathParameters['id']!;
              return OrderConfirmationScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'order/:id/tracking',
            name: 'order-tracking',
            builder: (context, state) {
              final orderId = state.pathParameters['id']!;
              return OrderTrackingScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'orders',
            name: 'order-history',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: 'profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
