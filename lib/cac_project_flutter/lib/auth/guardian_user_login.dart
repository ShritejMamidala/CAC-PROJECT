import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class GuardianLoginPage extends StatelessWidget {
  const GuardianLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
  AuthService.instance.signInAsGuardian();
  Navigator.pushReplacementNamed(context, '/guardian');
},
          child: const Text('Login as Guardian (stub)'),
        ),
      ),
    );
  }
}
