import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BlindMainPage extends StatelessWidget {
  const BlindMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blindside Home')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Welcome to BlindSide!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28),
              Text(
                'This is your main page to use this app!\n\n'
                'At the bottom of the screen, there is the ability to start navigation and see your camera.\n\n'
                'Ensure that the video is visible at all times to maintain accurate detection.\n\n'
                'Upon signing up, you will have received a guardian pairing code. '
                'Please share that code with your guardian so they can view your camera feed in real time.\n\n'
                'Once permissions are granted, BlindSide will help you navigate safely using AI, depth detection, and live feedback.',
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

/// Call this once before opening your Camera/Nav screens.
/// Returns true if both Camera + Location are ready to use.
class PermissionGate {
  static Future<bool>? _inFlight; // prevents overlapping requests

  static Future<bool> requestCorePermissionsOnce(BuildContext context) {
    _inFlight ??= _doRequest(context);
    return _inFlight!.whenComplete(() => _inFlight = null);
  }

  static Future<bool> _doRequest(BuildContext context) async {
    // Request both at once
    final results = await [Permission.camera, Permission.location].request();

    final cam = results[Permission.camera];
    final loc = results[Permission.location];

    // If either is permanently denied, send user to settings
    if (cam?.isPermanentlyDenied == true || loc?.isPermanentlyDenied == true) {
      _snack(context, 'Enable permissions in Settings');
      await openAppSettings();
      return false;
    }

    // If still denied, bail
    if (cam?.isGranted != true || loc?.isGranted != true) {
      _snack(context, 'Camera & Location are required');
      return false;
    }

    // Optional: check if location services (GPS) are ON
    final service = await Permission.location.serviceStatus;
    if (!service.isEnabled) {
      _snack(context, 'Turn on Location Services (GPS)');
      return false;
    }

    return true;
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
