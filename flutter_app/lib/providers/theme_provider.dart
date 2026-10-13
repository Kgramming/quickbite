import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_themes.dart';
import '../services/local_storage.dart';

/// Manages the user's selected theme, persisted via LocalStorageService.
///
/// Switching themes rebuilds [MaterialApp] with the new [ThemeData] but
/// does NOT touch auth state, cart, or navigation — the user's workflow
/// is preserved.
class ThemeModeNotifier extends StateNotifier<QuickBiteThemeMode> {
  final LocalStorageService _storage;

  ThemeModeNotifier(this._storage)
      : super(QuickBiteThemeMode.fromStorage(_storage.getThemeMode()));

  Future<void> setTheme(QuickBiteThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _storage.saveThemeMode(mode.toStorage());
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, QuickBiteThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

/// Resolved tokens for the currently selected theme.
/// Screens should read colors from here, not hardcode them.
final themeTokensProvider = Provider<QuickBiteTokens>((ref) {
  final mode = ref.watch(themeModeProvider);
  return QuickBiteThemes.of(mode);
});
