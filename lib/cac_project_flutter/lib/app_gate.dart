// lib/app_gate.dart
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'auth/blind_user_login.dart';
import 'blind/blind_shell.dart';
import 'guardian/guardian_shell.dart';

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          // Not logged in
          return const BlindLoginPage();
        }

        if (user.role == UserRole.blind) {
          // Logged in as blind user
          return const BlindShell();
        }

        // Logged in as guardian
        return const GuardianShell();
      },
    );
  }
}
