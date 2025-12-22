import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // 1. Импорт
import 'theme/app_theme.dart';
import 'screens/main_wrapper.dart';




void main() {
  // 2. Инициализация привязки
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // 3. ЗАМОРАЖИВАЕМ сплэш-экран (он не исчезнет сам)
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const TennisApp());
}

class TennisApp extends StatelessWidget {
  const TennisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Tennis Club',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const MainWrapper(),
        );
      },
    );
  }
}