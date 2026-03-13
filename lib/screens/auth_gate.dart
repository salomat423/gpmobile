import 'package:flutter/material.dart';
import '../core/di/app_scope.dart';
import '../core/storage/token_storage.dart';
import 'auth_screen.dart';
import 'main_wrapper.dart';
import 'trainer_main_wrapper.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthState>(
      valueListenable: AppScope.instance.authState,
      builder: (context, state, _) {
        if (state == AuthState.unknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state != AuthState.authenticated) {
          return const AuthScreen();
        }
        return FutureBuilder<String?>(
          future: TokenStorage.instance.readRole(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = (snap.data ?? '').toUpperCase();
            final isCoach = role == 'COACH_PADEL' || role == 'COACH_FITNESS' || role == 'COACH_GYM';
            return isCoach ? const TrainerMainWrapper() : const MainWrapper();
          },
        );
      },
    );
  }
}
