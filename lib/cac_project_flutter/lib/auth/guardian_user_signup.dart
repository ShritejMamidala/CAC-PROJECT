import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GuardianSignupPage extends StatelessWidget {
  const GuardianSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Signup')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => AuthService.instance.signInAsGuardian(),
          child: const Text('Signup as Guardian (stub)'),
        ),
      ),
    );
  }
}
