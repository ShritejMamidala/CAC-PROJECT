import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BlindSignupPage extends StatelessWidget {
  const BlindSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blind Signup')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => AuthService.instance.signInAsBlind(),
          child: const Text('Signup as Blind (stub)'),
        ),
      ),
    );
  }
}
