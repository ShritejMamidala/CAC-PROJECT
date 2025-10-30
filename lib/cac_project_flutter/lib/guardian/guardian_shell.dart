import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'guardian_user_main.dart';
import 'guardian_watching.dart';

class GuardianShell extends StatefulWidget {
  const GuardianShell({super.key});

  @override
  State<GuardianShell> createState() => _GuardianShellState();
}

class _GuardianShellState extends State<GuardianShell> {
  int _index = 0;

  // For GuardianShell (Guardian)
  static const _livekitUrl = 'wss://blindside-jvsn35ln.livekit.cloud';
  static const _guardianToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2aWRlbyI6eyJyb29tSm9pbiI6dHJ1ZSwicm9vbSI6ImJsaW5kc2lkZS1yb29tIiwiY2FuUHVibGlzaCI6dHJ1ZSwiY2FuU3Vic2NyaWJlIjp0cnVlLCJjYW5QdWJsaXNoRGF0YSI6dHJ1ZX0sInN1YiI6Imd1YXJkaWFuLXVzZXIiLCJpc3MiOiJBUElDSkVZQllZeEJwUUQiLCJuYmYiOjE3NjE3OTc4MDAsImV4cCI6MTc2MTgxOTQwMH0.-184sFzmGZSG2m4tf4JF52ZC9WuooP4uDGDIzBCL7jE';
  
  late final _pages = [
    const GuardianMainPage(),
    GuardianWatchingPage(
      livekitUrl: _livekitUrl,
      guardianToken: _guardianToken,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian'),
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
          NavigationDestination(
            icon: Icon(Icons.remove_red_eye),
            label: 'Watching',
          ),
        ],
      ),
    );
  }
}
