import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import 'local_storage.dart';

/// QuickBite API Client using Dio
class QuickBiteApiClient {
  final Dio dio;
  final String baseUrl;

  QuickBiteApiClient({required this.dio, required this.baseUrl});

  // ==================== Auth ====================
  
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPath}/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<User> getMe() async {
    try {
      final response = await dio.get('${AppConfig.apiPath}/me');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ==================== Restaurants ====================

  Future<PaginatedRestaurants> getRestaurants({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/restaurants',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return PaginatedRestaurants.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<RestaurantMenu> getRestaurantMenu({
    required String restaurantId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/restaurants/$restaurantId/menu',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      return RestaurantMenu.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ==================== Orders ====================

  Future<Order> createOrder({
    required String restaurantId,
    required String deliveryAddress,
    required List<Map<String, dynamic>> items,
    required String idempotencyKey,
  }) async {
    try {
      final response = await dio.post(
        '${AppConfig.apiPath}/orders',
        data: {
          'restaurant_id': restaurantId,
          'delivery_address': deliveryAddress,
          'items': items,
        },
        options: Options(
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      );
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<PaginatedOrders> getOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/orders',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (status != null) 'status': status,
        },
      );
      return PaginatedOrders.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ==================== Admin (role-protected) ====================

  /// GET /api/v1/admin/orders — cross-customer order overview.
  /// Requires admin role (backend enforces via require_admin).
  Future<PaginatedOrders> getAdminOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/admin/orders',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (status != null) 'status': status,
        },
      );
      return PaginatedOrders.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// GET /api/v1/admin/summary — counts by status plus outbox/retry/
  /// quarantine backlog depths. Requires admin role.
  Future<AdminSummary> getAdminSummary() async {
    try {
      final response =
          await dio.get('${AppConfig.apiPath}/admin/summary');
      return AdminSummary.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final response = await dio.get('${AppConfig.apiPath}/orders/$orderId');
      return Order.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/orders/$orderId/history',
      );
      final list = response.data as List;
      return list
          .map((item) => OrderStatusHistory.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<List<OrderNotification>> getOrderNotifications({
    required String orderId,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await dio.get(
        '${AppConfig.apiPath}/orders/$orderId/notifications',
        queryParameters: {'page': page, 'page_size': pageSize},
      );
      final list = response.data as List;
      return list
          .map((item) => OrderNotification.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ==================== Health ====================

  Future<HealthResponse> getHealthLive() async {
    try {
      final response = await dio.get('/health/live');
      return HealthResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<HealthResponse> getHealthReady() async {
    try {
      final response = await dio.get('/health/ready');
      return HealthResponse.fromJson(response.data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // ==================== Error Handling ====================

  void _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String?;
        final code = data['code'] as String?;
        print('API Error [$code]: $message');
      }
    }
    print('DioException: ${error.message}');
  }
}

class HealthResponse {
  final String status;
  final Map<String, dynamic>? dependencies;

  HealthResponse({required this.status, this.dependencies});

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String? ?? 'unknown',
      dependencies: json['dependencies'] as Map<String, dynamic>?,
    );
  }
}

// ==================== Providers ====================

/// Reads the current auth token from storage.
///
/// NOTE: [localStorageProvider] is a plain Provider that never notifies, so
/// this provider evaluates once. The auth interceptor below does NOT rely on
/// this value being reactive — it reads the live storage service on every
/// request (see [_AuthInterceptor]), so login/logout are always reflected.
final rawTokenProvider = Provider<String?>((ref) {
  return ref.watch(localStorageProvider).getToken();
});

/// Dio interceptor that attaches `Authorization: Bearer <token>` to every
/// outgoing request (except the login endpoint).
///
/// Reads the token from [LocalStorageService] on EACH request — never caches
/// it — so the header is always fresh after login, and absent after logout.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    // Never attach auth to the login call itself.
    final isLogin = options.path.endsWith('/auth/login');
    if (!isLogin) {
      // Live read: LocalStorageService.getToken() hits the open Hive box
      // synchronously, so this is always the current token.
      final token = _ref.read(localStorageProvider).getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      sendTimeout: AppConfig.requestTimeout,
      contentType: 'application/json',
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_AuthInterceptor(ref));

  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print(obj),
    ),
  );

  return dio;
});

final apiClientProvider = Provider<QuickBiteApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return QuickBiteApiClient(dio: dio, baseUrl: AppConfig.baseUrl);
});

/// Authenticated Dio — same instance as [dioProvider]; the [_AuthInterceptor]
/// attaches the bearer token per request. Kept as a separate provider for
/// readability at call sites that require authentication.
final authenticatedDioProvider = Provider<Dio>((ref) {
  return ref.watch(dioProvider);
});

final authenticatedApiClientProvider =
    Provider<QuickBiteApiClient>((ref) {
  final dio = ref.watch(authenticatedDioProvider);
  return QuickBiteApiClient(dio: dio, baseUrl: AppConfig.baseUrl);
});
