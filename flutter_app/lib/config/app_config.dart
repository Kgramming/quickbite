import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8002',
  );

  static const String apiVersion = 'v1';
  static const String apiPath = '/api/v1';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Storage keys
  static const String tokenKey = 'access_token';
  static const String userKey = 'user_data';
  static const String ordersKey = 'orders_cache';
}

final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.baseUrl);
