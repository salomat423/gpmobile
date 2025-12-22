import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          home: const AuthGate(isLoggedIn: false),
        );
      },
    );
  }
}