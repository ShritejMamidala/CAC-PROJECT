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
  final _pages = const [BlindMainPage(), BlindGPSPage(), BlindCameraPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          )
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
