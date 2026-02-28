import 'package:flutter/material.dart';
import '../core/di/app_scope.dart';
import 'auth_screen.dart';
import 'main_wrapper.dart';

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
        return state == AuthState.authenticated ? const MainWrapper() : const AuthScreen();
      },
    );
  }
}