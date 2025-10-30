import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'blind_user_main.dart';
import 'blind_user_gps.dart';
import 'blind_user_camera.dart';

class BlindShell extends StatefulWidget {
  const BlindShell({super.key});

  @override
  State<BlindShell> createState() => _BlindShellState();
}

class _BlindShellState extends State<BlindShell> {
  int _index = 0;

  // For BlindShell (Navigator)
  static const _livekitUrl = 'wss://blindside-jvsn35ln.livekit.cloud';
  static const _navigatorToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2aWRlbyI6eyJyb29tSm9pbiI6dHJ1ZSwicm9vbSI6ImJsaW5kc2lkZS1yb29tIiwiY2FuUHVibGlzaCI6dHJ1ZSwiY2FuU3Vic2NyaWJlIjp0cnVlLCJjYW5QdWJsaXNoRGF0YSI6dHJ1ZX0sInN1YiI6ImJsaW5kLXVzZXIiLCJpc3MiOiJBUElDSkVZQllZeEJwUUQiLCJuYmYiOjE3NjE3ODYwODAsImV4cCI6MTc2MTgwNzY4MH0.1Aaqvn-LtKBe7yQmSPaXRqw3D8BhvtBKQrfelZnSYKA';

  late final _pages = [
    const BlindMainPage(),
    const BlindGPSPage(),
    BlindCameraPage(
      livekitUrl: _livekitUrl,
      navigatorToken: _navigatorToken,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              AuthService.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Main'),
          NavigationDestination(icon: Icon(Icons.pin_drop), label: 'GPS'),
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Camera'),
        ],
      ),
    );
  }
}