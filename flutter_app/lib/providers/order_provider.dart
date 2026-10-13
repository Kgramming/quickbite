import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../services/api_client.dart';

final ordersListProvider = FutureProvider.family<PaginatedOrders, int>(
  (ref, page) async {
    final apiClient = ref.watch(authenticatedApiClientProvider);
    return apiClient.getOrders(page: page, pageSize: 20);
  },
);

final orderDetailProvider = FutureProvider.family<Order, String>(
  (ref, orderId) async {
    final apiClient = ref.watch(authenticatedApiClientProvider);
    return apiClient.getOrder(orderId);
  },
);

final orderHistoryProvider = FutureProvider.family<List<OrderStatusHistory>, String>(
  (ref, orderId) async {
    final apiClient = ref.watch(authenticatedApiClientProvider);
    return apiClient.getOrderHistory(orderId);
  },
);

final orderNotificationsProvider =
    FutureProvider.family<List<OrderNotification>, (String, int)>(
  (ref, params) async {
    final (orderId, page) = params;
    final apiClient = ref.watch(authenticatedApiClientProvider);
    return apiClient.getOrderNotifications(orderId: orderId, page: page, pageSize: 50);
  },
);

// ==================== Admin ====================

/// Admin order overview: paginated, filterable by status.
/// Backend enforces admin role; 403 otherwise.
final adminOrdersProvider =
    FutureProvider.family<PaginatedOrders, ({int page, String? status})>(
  (ref, params) async {
    final apiClient = ref.watch(authenticatedApiClientProvider);
    return apiClient.getAdminOrders(
      page: params.page,
      pageSize: 20,
      status: params.status,
    );
  },
);

/// Admin summary: counts by status + outbox/retry/quarantine depths.
final adminSummaryProvider = FutureProvider<AdminSummary>((ref) async {
  final apiClient = ref.watch(authenticatedApiClientProvider);
  return apiClient.getAdminSummary();
});

class CheckoutState {
  final String? orderId;
  final Order? order;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const CheckoutState({
    this.orderId,
    this.order,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  CheckoutState copyWith({
    String? orderId,
    Order? order,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return CheckoutState(
      orderId: orderId ?? this.orderId,
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }

  void clearError() {
    // This is a helper, but since CheckoutState is immutable,
    // it's better to clear via the notifier
  }
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final QuickBiteApiClient apiClient;

  CheckoutNotifier({required this.apiClient}) : super(const CheckoutState());

  Future<String> createOrder({
    required String restaurantId,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final idempotencyKey = Uuid().v4();

      final order = await apiClient.createOrder(
        restaurantId: restaurantId,
        deliveryAddress: deliveryAddress,
        items: items,
        idempotencyKey: idempotencyKey,
      );

      state = state.copyWith(
        orderId: order.id,
        order: order,
        isLoading: false,
        successMessage: 'Order placed successfully!',
      );

      return order.id;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> fetchOrderStatus(String orderId) async {
    try {
      final order = await apiClient.getOrder(orderId);
      state = state.copyWith(order: order);
    } catch (e) {
      state = state.copyWith(error: _extractErrorMessage(e));
    }
  }

  void clearState() {
    state = const CheckoutState();
  }

  String _extractErrorMessage(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message != null) {
          return message as String;
        }
        final details = data['details'];
        if (details is Map<String, dynamic>) {
          return details.values.first.toString();
        }
      }
      return error.message ?? 'Network error';
    }
    return error.toString();
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  final apiClient = ref.watch(authenticatedApiClientProvider);
  return CheckoutNotifier(apiClient: apiClient);
});

// Auto-refresh order status
final orderStatusRefreshProvider = StreamProvider.family<Order, String>(
  (ref, orderId) async* {
    final apiClient = ref.watch(authenticatedApiClientProvider);

    while (true) {
      try {
        final order = await apiClient.getOrder(orderId);
        yield order;

        // Stop polling if order is in terminal state
        if (order.isTerminal) {
          break;
        }

        // Wait 2 seconds before next poll
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error fetching order status: $e');
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  },
);
