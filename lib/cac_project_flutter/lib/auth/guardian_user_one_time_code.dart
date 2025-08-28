import 'package:flutter/material.dart';

/// Route name suggestion: '/guardian_user_one_time_code'
class GuardianUserOneTimeCodePage extends StatelessWidget {
  const GuardianUserOneTimeCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian: One-Time Code')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // For now, skip code validation and go straight to guardian main page
            Navigator.pushReplacementNamed(context, '/guardian');
          },
          child: const Text('Continue to Guardian Dashboard'),
        ),
      ),
    );
  }
}
