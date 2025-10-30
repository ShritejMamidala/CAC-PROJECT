import 'package:flutter/material.dart';

class GuardianMainPage extends StatelessWidget {
  const GuardianMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Home')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Welcome to BlindSide Guardian!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28),
              Text(
                'This is your main page as a Guardian.\n\n'
                'Your role is to assist the BlindSide user by monitoring their live camera feed in real time.\n\n'
                'Once you receive their pairing code, enter it in the connection screen to link with their device.\n\n'
                'After pairing, you will be able to view their surroundings, provide voice or visual guidance, '
                'and help them navigate safely.\n\n'
                'Ensure you have a stable internet connection for smooth, real-time video streaming.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
