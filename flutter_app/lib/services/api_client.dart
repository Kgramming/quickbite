import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retrofit/retrofit.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/restaurant.dart';

part 'api_client.g.dart';

@RestApi()
abstract class QuickBiteApiClient {
  factory QuickBiteApiClient(Dio dio, {String? baseUrl}) = _QuickBiteApiClient;

  // Auth endpoints
  @POST('${AppConfig.apiPath}/auth/login')
  Future<AuthResponse> login(
    @Body() Map<String, String> credentials,
  );

  @GET('${AppConfig.apiPath}/me')
  Future<User> getMe();

  // Restaurant endpoints
  @GET('${AppConfig.apiPath}/restaurants')
  Future<PaginatedRestaurants> getRestaurants(
    @Query('page') int page,
    @Query('page_size') int pageSize,
  );

  @GET('${AppConfig.apiPath}/restaurants/{id}/menu')
  Future<RestaurantMenu> getRestaurantMenu(
    @Path('id') String restaurantId,
    @Query('page') int page,
    @Query('page_size') int pageSize,
  );

  // Order endpoints
  @POST('${AppConfig.apiPath}/orders')
  Future<Order> createOrder(
    @Body() Map<String, dynamic> orderRequest,
    @Header('Idempotency-Key') String idempotencyKey,
  );

  @GET('${AppConfig.apiPath}/orders')
  Future<PaginatedOrders> getOrders(
    @Query('page') int page,
    @Query('page_size') int pageSize,
    @Query('status') String? status,
  );

  @GET('${AppConfig.apiPath}/orders/{id}')
  Future<Order> getOrder(@Path('id') String orderId);

  @GET('${AppConfig.apiPath}/orders/{id}/history')
  Future<List<OrderStatusHistory>> getOrderHistory(
    @Path('id') String orderId,
  );

  @GET('${AppConfig.apiPath}/orders/{id}/notifications')
  Future<List<OrderNotification>> getOrderNotifications(
    @Path('id') String orderId,
    @Query('page') int page,
    @Query('page_size') int pageSize,
  );

  // Health endpoints
  @GET('/health/live')
  Future<HealthResponse> getHealthLive();

  @GET('/health/ready')
  Future<HealthResponse> getHealthReady();
}

class HttpClientFactory {
  static Dio createDio(String baseUrl, String? token) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        sendTimeout: AppConfig.requestTimeout,
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    // Add logging interceptor
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print(obj),
      ),
    );

    // Add retry interceptor
    dio.interceptors.add(RetryInterceptor(dio));

    return dio;
  }
}

class RetryInterceptor extends Interceptor {
  final Dio dio;

  RetryInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Retry logic for network errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.unknown) {
      // Simple retry: you can enhance this with exponential backoff
      handler.next(err);
    } else {
      handler.next(err);
    }
  }
}

class ApiErrorException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final String? requestId;

  ApiErrorException({
    required this.code,
    required this.message,
    this.details,
    this.requestId,
  });

  @override
  String toString() => 'ApiErrorException: [$code] $message';
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

final dioProvider = Provider<Dio>((ref) {
  return HttpClientFactory.createDio(AppConfig.baseUrl, null);
});

final apiClientProvider = Provider<QuickBiteApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return QuickBiteApiClient(dio, baseUrl: AppConfig.baseUrl);
});

final authenticatedDioProvider = Provider<Dio>((ref) {
  // This will be overridden in the auth provider to include token
  return HttpClientFactory.createDio(AppConfig.baseUrl, null);
});

final authenticatedApiClientProvider =
    Provider<QuickBiteApiClient>((ref) {
  final dio = ref.watch(authenticatedDioProvider);
  return QuickBiteApiClient(dio, baseUrl: AppConfig.baseUrl);
});
