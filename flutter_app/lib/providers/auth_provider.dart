import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/local_storage.dart';

class AuthState {
  final String? token;
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    String? token,
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final QuickBiteApiClient apiClient;
  final LocalStorageService localStorageService;

  AuthNotifier({
    required this.apiClient,
    required this.localStorageService,
  }) : super(const AuthState());

  Future<void> initializeAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = localStorageService.getToken();
      final userJson = localStorageService.getUser();

      if (token != null && userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userData);
        state = AuthState(
          token: token,
          user: user,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize auth: $e',
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await apiClient.login(
        email: email,
        password: password,
      );

      await localStorageService.saveToken(response.accessToken);
      await localStorageService.saveUser(jsonEncode(response.user));

      state = AuthState(
        token: response.accessToken,
        user: response.user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await localStorageService.clearAll();
      state = const AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to logout: $e',
      );
    }
  }

  String _extractErrorMessage(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? 'An error occurred';
      }
      return error.message ?? 'Network error';
    }
    return error.toString();
  }
}

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final localStorage = ref.watch(localStorageProvider);

  return AuthNotifier(
    apiClient: apiClient,
    localStorageService: localStorage,
  );
});

// Convenience providers
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});

final authTokenProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.token;
});

// Command providers for login/logout
final loginCommandProvider =
    FutureProvider.family<void, (String, String)>((ref, params) async {
  final (email, password) = params;
  final authNotifier = ref.read(authStateProvider.notifier);
  await authNotifier.login(email: email, password: password);
});

final logoutCommandProvider = FutureProvider<void>((ref) async {
  final authNotifier = ref.read(authStateProvider.notifier);
  await authNotifier.logout();
});
