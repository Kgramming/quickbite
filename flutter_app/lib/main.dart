import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/app_themes.dart';
import 'config/router.dart';
import 'providers/theme_provider.dart';
import 'services/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Open Hive boxes BEFORE the app starts. LocalStorageService uses `late`
  // Box fields that throw LateInitializationError if init() is never called
  // (previously the cause of silent auth failures on startup).
  final localStorage = LocalStorageService();
  await localStorage.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
      ],
      child: const QuickBiteApp(),
    ),
  );
}

class QuickBiteApp extends ConsumerWidget {
  const QuickBiteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final tokens = QuickBiteThemes.of(themeMode);

    return MaterialApp.router(
      title: 'QuickBite',
      theme: QuickBiteThemes.themeData(tokens),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
