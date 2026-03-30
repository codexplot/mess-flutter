import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _roomCodeCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isMember = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _roomCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      roomCode: _isMember ? _roomCodeCtrl.text.trim() : null,
    );
    if (!mounted) return;
    if (ok) {
      showSnack(context, 'Account created successfully!');
      Navigator.pop(context);
    } else {
      showSnack(context, auth.error ?? 'Registration failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create account',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Join RoomMess to manage shared expenses',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 32),

              // Role selector
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isMember = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isMember ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: !_isMember ? AppTheme.navy : const Color(0xFFDDE3EE)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: !_isMember ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(height: 4),
                            Text('Owner',
                                style: TextStyle(
                                    color: !_isMember ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isMember = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isMember ? AppTheme.teal : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _isMember ? AppTheme.teal : const Color(0xFFDDE3EE)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person,
                                color: _isMember ? Colors.white : AppTheme.textSecondary),
                            const SizedBox(height: 4),
                            Text('Member',
                                style: TextStyle(
                                    color: _isMember ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) => v != _passCtrl.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    if (_isMember) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _roomCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Room code (6 characters)',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                          hintText: 'e.g. ABC123',
                        ),
                        validator: (v) => _isMember && (v == null || v.length != 6)
                            ? 'Enter a valid 6-character room code'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 28),
                    LoadingButton(
                      loading: loading,
                      onPressed: _register,
                      label: 'Create Account',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Sign in',
                              style: TextStyle(
                                  color: AppTheme.teal, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
