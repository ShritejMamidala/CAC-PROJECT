import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BlindLoginPage extends StatelessWidget {
  const BlindLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blind Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            AuthService.instance.signInAsBlind();
            Navigator.pushReplacementNamed(context, '/blind'); // 👈 jump straight in
          },
          child: const Text('Login as Blind (stub)'),
        ),
      ),
    );
  }
}
