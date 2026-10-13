import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

class LocalStorageService {
  static const String _tokenBoxName = 'quickbite_tokens';
  static const String _userBoxName = 'quickbite_users';
  static const String _ordersBoxName = 'quickbite_orders';

  late Box<String> _tokenBox;
  late Box<String> _userBox;
  late Box<String> _ordersBox;
  late Box<String> _prefsBox;

  Future<void> init() async {
    _tokenBox = await Hive.openBox<String>(_tokenBoxName);
    _userBox = await Hive.openBox<String>(_userBoxName);
    _ordersBox = await Hive.openBox<String>(_ordersBoxName);
    _prefsBox = await Hive.openBox<String>(_themeBoxName);
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _tokenBox.put(AppConfig.tokenKey, token);
  }

  String? getToken() {
    return _tokenBox.get(AppConfig.tokenKey);
  }

  Future<void> deleteToken() async {
    await _tokenBox.delete(AppConfig.tokenKey);
  }

  // User management
  Future<void> saveUser(String userJson) async {
    await _userBox.put(AppConfig.userKey, userJson);
  }

  String? getUser() {
    return _userBox.get(AppConfig.userKey);
  }

  Future<void> deleteUser() async {
    await _userBox.delete(AppConfig.userKey);
  }

  // Orders caching
  Future<void> saveOrders(String ordersJson) async {
    await _ordersBox.put(AppConfig.ordersKey, ordersJson);
  }

  String? getOrders() {
    return _ordersBox.get(AppConfig.ordersKey);
  }

  Future<void> deleteOrders() async {
    await _ordersBox.delete(AppConfig.ordersKey);
  }

  // Theme preference
  static const String _themeBoxName = 'quickbite_prefs';
  static const String _themeKey = 'theme_mode';

  Future<void> saveThemeMode(String mode) async {
    await _prefsBox.put(_themeKey, mode);
  }

  String? getThemeMode() {
    return _prefsBox.get(_themeKey);
  }

  // Clear all
  Future<void> clearAll() async {
    await _tokenBox.clear();
    await _userBox.clear();
    await _ordersBox.clear();
  }
}

final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});
