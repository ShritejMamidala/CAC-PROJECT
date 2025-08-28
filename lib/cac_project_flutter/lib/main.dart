import 'package:flutter/material.dart';
import 'dart:math' as math;

// bring in the rest of your app
import 'app_gate.dart';
import 'auth/blind_user_login.dart';
import 'auth/blind_user_signup.dart';
import 'auth/guardian_user_one_time_code.dart';
import 'blind/blind_shell.dart';
import 'guardian/guardian_shell.dart';
import 'services/auth_service.dart';


import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const deepPurple = Color.fromARGB(255, 99, 99, 99);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark().copyWith(
          primary: deepPurple,
          surface: deepPurple,
        ),
        scaffoldBackgroundColor: deepPurple,
      ),
      home: const HomePage(), // ← app starts here
      routes: {
      '/appgate': (_) => const AppGate(),   // 👈 add this
      '/auth/blind/login': (_) => const BlindLoginPage(),
      '/auth/blind/signup': (_) => const BlindSignupPage(),
      '/auth/guardian/one_time_code': (_) => const GuardianUserOneTimeCodePage(),
      '/blind': (_) => const BlindShell(),
      '/guardian': (_) => const GuardianShell(),
      },
    );
  }
}

/// -------------------------
/// Fancy animated HomePage
/// -------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final sidePadding = w * 0.08;
    final verticalGap = h * 0.02;
    final bigGap = h * 0.04;
    final buttonHeight = h * 0.11;
    final radius = w * 0.06;
    final titleSize = w * 0.08;
    final labelSize = w * 0.05;

    return Scaffold(
      body: Stack(
        children: [
          // animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: _HexMeshPainter(
                  progress: _controller.value,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              child: Column(
                children: [
                  SizedBox(height: bigGap * 4),
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          const LinearGradient(colors: [
                        Colors.white,
                        Colors.white,
                      ]).createShader(bounds),
                      child: Text(
                        'BLINDSIDE',
                        style: TextStyle(
                          fontSize: titleSize.clamp(60, 80),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ModeButton(
                          label: 'Blind Mode',
                          color: const Color(0xFF0A2E5C),
                          height: buttonHeight,
                          radius: radius,
                          icon: Icons.visibility_off_rounded,
                          labelSize: labelSize * 8,
                          onPressed: () {
                          final user = AuthService.instance.currentUser;
                          if (user == null) {
                            Navigator.pushNamed(context, '/auth/blind/login');
                          } else {
                            final route = user.role == UserRole.blind ? '/blind' : '/guardian';
                            Navigator.pushNamed(context, route);
                          }
                        },
                          semanticsLabel: 'Enter Blind Mode',
                        ),
                        SizedBox(height: verticalGap * 4),
                        _ModeButton(
                          label: 'Guardian Mode',
                          color: const Color(0xFF1C3B2D),
                          height: buttonHeight,
                          radius: radius,
                          icon: Icons.supervisor_account_rounded,
                          labelSize: labelSize * 8,
                          onPressed: () {
                          final user = AuthService.instance.currentUser;
                          if (user == null) {
                            Navigator.pushNamed(context, '/auth/guardian/one_time_code');
                          } else {
                            final route = user.role == UserRole.blind ? '/blind' : '/guardian';
                            Navigator.pushNamed(context, route);
                          }
                        },
                          semanticsLabel: 'Enter Guardian Mode',
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: settings
                    },
                    child: const Text('Settings'),
                  ),
                  SizedBox(height: verticalGap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final Color color;
  final double height;
  final double radius;
  final IconData icon;
  final double labelSize;
  final VoidCallback onPressed;
  final String semanticsLabel;
  const _ModeButton({
    required this.label,
    required this.color,
    required this.height,
    required this.radius,
    required this.icon,
    required this.labelSize,
    required this.onPressed,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: EdgeInsets.symmetric(
          vertical: height * 0.18,
          horizontal: w * 0.06,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: (labelSize * 1.2).clamp(20, 28)),
          SizedBox(width: w * 0.02),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: labelSize.clamp(16, 24),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _HexMeshPainter extends CustomPainter {
  final double progress;
  final Color color;
  _HexMeshPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF0B0B0D), Color(0xFF101418)],
        stops: [0.0, 0.3, 0.7],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, gradientPaint);

    void drawWave(
        {required double baseY,
        required double amplitude,
        required double frequency,
        required double phaseShift,
        required double thickness,
        required double opacity,
        required double speed}) {
      final path = Path();
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness;

      final phase = (progress * 2 * math.pi * speed) + phaseShift;
      final h = size.height;
      final w = size.width;

      double y(double x) =>
          baseY * h +
          math.sin((x / w) * 2 * math.pi * frequency + phase) * (amplitude * h);

      const step = 8.0;
      path.moveTo(0, y(0));
      for (double x = step; x <= w; x += step) {
        path.lineTo(x, y(x));
      }
      canvas.drawPath(path, paint);
    }

    drawWave(
        baseY: 0.30,
        amplitude: 0.06,
        frequency: 1.2,
        phaseShift: 0,
        thickness: 1.5,
        opacity: 0.1,
        speed: 0.8);

    drawWave(
        baseY: 0.55,
        amplitude: 0.05,
        frequency: 0.9,
        phaseShift: math.pi / 2,
        thickness: 1.2,
        opacity: 0.07,
        speed: 1.0);

    drawWave(
        baseY: 0.78,
        amplitude: 0.04,
        frequency: 1.4,
        phaseShift: math.pi,
        thickness: 1.0,
        opacity: 0.05,
        speed: 1.25);
  }

  @override
  bool shouldRepaint(covariant _HexMeshPainter old) =>
      old.progress != progress || old.color != color;
}