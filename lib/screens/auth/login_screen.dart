import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/expense_provider.dart';
import '../../main.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorMsg;
  int _failedAttempts = 0;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authProvider = context.read<AuthProvider>();
        _authProvider!.addListener(_onAuthChange);
      }
    });
  }

  void _onAuthChange() {
    final auth = _authProvider;
    if (auth != null && auth.isAuthenticated && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChange);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }
    if (pass.length < 6) {
      _showSnackBar('Password must be at least 6 characters.');
      return;
    }

    setState(() { _errorMsg = null; _loading = true; });
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email,
      pass,
      roomProvider: context.read<RoomProvider>(),
      expenseProvider: context.read<ExpenseProvider>(),
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (!ok) {
      final msg = auth.error ?? 'Invalid email or password';
      setState(() {
        _failedAttempts++;
        _errorMsg = msg;
        _passCtrl.clear();
      });
      _showSnackBar(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 24),
                  const Text('Welcome back',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Sign in to your RoomMess account',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() => _errorMsg = null),
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) =>
                              v == null || !v.contains('@') ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onChanged: (_) => setState(() => _errorMsg = null),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.length < 6 ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            child: const Text('Forgot password?',
                                style: TextStyle(color: AppTheme.teal, fontSize: 13)),
                          ),
                        ),

                        // Error banner
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.error.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: const TextStyle(color: AppTheme.error, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_failedAttempts >= 3) ...[
                                  const SizedBox(height: 8),
                                  const Divider(height: 1, color: Color(0xFFFFCDD2)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_reset, color: AppTheme.error, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const ForgotPasswordScreen()),
                                          ),
                                          child: RichText(
                                            text: const TextSpan(
                                              style: TextStyle(fontSize: 13),
                                              children: [
                                                TextSpan(
                                                  text: 'Too many failed attempts. ',
                                                  style: TextStyle(color: AppTheme.error),
                                                ),
                                                TextSpan(
                                                  text: 'Reset your password →',
                                                  style: TextStyle(
                                                    color: AppTheme.error,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        LoadingButton(
                          loading: _loading,
                          onPressed: _login,
                          label: 'Sign In',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('New user? ',
                                style: TextStyle(color: AppTheme.textSecondary)),
                            GestureDetector(
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              child: const Text('Create account',
                                  style: TextStyle(
                                      color: AppTheme.teal, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  final String name;
  const _SuccessDialog({required this.name});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 20),
            const Text('You\'re logged in!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Welcome back${widget.name.isNotEmpty ? ', ${widget.name}' : ''}! 👋',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
