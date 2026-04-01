import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _email;
  String? _userName;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showSnack(context, 'Enter a valid email', error: true);
      return;
    }
    setState(() => _loading = true);
    final res = await ApiService.post('/auth/forgot-password', {'email': email}, auth: false);
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success']) {
      setState(() {
        _otpSent = true;
        _email = email;
        _userName = res['data']['name'];
        // Show OTP directly (no email configured)
        _otpCtrl.text = res['data']['otp'] ?? '';
      });
      showSnack(context, 'Reset code sent! (pre-filled for you)');
    } else {
      showSnack(context, res['message'] ?? 'Failed to send code', error: true);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (otp.length != 6) {
      showSnack(context, 'Enter the 6-digit reset code', error: true);
      return;
    }
    if (newPass.length < 6) {
      showSnack(context, 'Password must be at least 6 characters', error: true);
      return;
    }
    if (newPass != confirm) {
      showSnack(context, 'Passwords do not match', error: true);
      return;
    }

    setState(() => _loading = true);
    final res = await ApiService.post('/auth/reset-password', {
      'email': _email,
      'otp': otp,
      'newPassword': newPass,
    }, auth: false);
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success']) {
      showSnack(context, 'Password reset! Please log in.');
      Navigator.pop(context);
    } else {
      showSnack(context, res['message'] ?? 'Reset failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_reset, color: AppTheme.teal, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              _otpSent ? 'Enter reset code' : 'Forgot your password?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent
                  ? 'A reset code was generated for ${_userName ?? _email}. Enter it below along with your new password.'
                  : 'Enter your registered email and we\'ll generate a reset code for you.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),

            if (!_otpSent) ...[
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: _loading,
                onPressed: _requestOtp,
                label: 'Get Reset Code',
              ),
            ] else ...[
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit reset code',
                  prefixIcon: Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPassCtrl,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LoadingButton(
                loading: _loading,
                onPressed: _resetPassword,
                label: 'Reset Password',
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _otpSent = false;
                    _otpCtrl.clear();
                    _newPassCtrl.clear();
                    _confirmPassCtrl.clear();
                  }),
                  child: const Text('Use a different email', style: TextStyle(color: AppTheme.teal)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
