// auth/guardian_user_one_time_code.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

/// Route: '/auth/guardian/one_time_code'
class GuardianUserOneTimeCodePage extends StatefulWidget {
  const GuardianUserOneTimeCodePage({super.key});

  @override
  State<GuardianUserOneTimeCodePage> createState() => _GuardianUserOneTimeCodePageState();
}

class _GuardianUserOneTimeCodePageState extends State<GuardianUserOneTimeCodePage> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final blindUid = await AuthService.instance.resolveBlindUidByGuardianCode(code);
      if (blindUid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid code. Double-check and try again.')),
        );
        return;
      }

      // (Optional) store blindUid somewhere if your guardian pages need it.
      // For demo, we just continue to the guardian dashboard:
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/guardian');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const maxWidth = 420.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Guardian: Pairing Code')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the 6-digit pairing code provided by the blind user.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Pairing Code',
                    hintText: 'e.g., 123456',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _loading ? null : _verify(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Verify & Continue'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
