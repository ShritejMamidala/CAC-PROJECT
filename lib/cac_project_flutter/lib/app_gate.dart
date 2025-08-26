import 'dart:async';
import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});
  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  late final StreamSubscription<AppUser?> _sub; // 👈 keep handle to cancel
  bool _navigated = false;                      // 👈 prevent double nav

  @override
  void initState() {
    super.initState();

    _sub = AuthService.instance.authStateChanges.listen((user) {
      if (!mounted || _navigated) return;

      _navigated = true; // ensure we only navigate once per mount

      final route = (user == null)
          ? '/auth/blind/login'
          : (user.role == UserRole.blind ? '/blind' : '/guardian');

      // Defer to next frame → avoids “during build” navigation issues.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, route);
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel(); // 👈 stop listening when widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
