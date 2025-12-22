import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'main_wrapper.dart';

class AuthGate extends StatelessWidget {
  final bool isLoggedIn; // пока мок

  const AuthGate({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return isLoggedIn ? const MainWrapper() : const AuthScreen();
  }
}