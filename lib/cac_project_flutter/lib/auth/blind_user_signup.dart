// auth/blind_user_signup.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BlindSignupPage extends StatefulWidget {
  const BlindSignupPage({super.key});

  @override
  State<BlindSignupPage> createState() => _BlindSignupPageState();
}

class _BlindSignupPageState extends State<BlindSignupPage> {
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  int? _day;
  int? _month;
  int? _year;

  final List<int> _days = List<int>.generate(31, (i) => i + 1);
  final List<int> _months = List<int>.generate(12, (i) => i + 1);
  late final List<int> _years;
  static const List<String> _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    final nowYear = DateTime.now().year;
    _years = List<int>.generate(100, (i) => nowYear - i);
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/auth/blind/login');
    }
  }

Future<void> _register() async {
  DateTime? birthDate;
  if (_year != null && _month != null && _day != null) {
    birthDate = DateTime(_year!, _month!, _day!);
  }

  try {
    await AuthService.instance.signUpBlind(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstController.text.trim(),
      lastName: _lastController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      birthDate: birthDate,
    );

    if (!mounted) return;
    _goToLogin();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Sign up failed: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    const maxWidth = 520.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Blind Signup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Register',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'already have an account? ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _goToLogin,
                        child: Text(
                          'Log in',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Birth date',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _day,
                        items: _days
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d.toString()),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _day = v),
                        decoration: const InputDecoration(
                          labelText: 'Day',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _month,
                        items: List<DropdownMenuItem<int>>.generate(
                          _months.length,
                          (i) => DropdownMenuItem(
                            value: _months[i],
                            child: Text(_monthNames[i]),
                          ),
                        ),
                        onChanged: (v) => setState(() => _month = v),
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _year,
                        items: _years
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(y.toString()),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _year = v),
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Set password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _register,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Register'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
