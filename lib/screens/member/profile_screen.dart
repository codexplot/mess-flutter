import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _savingInfo = false;
  bool _savingPass = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? '';
    _emailCtrl.text = user?.email ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _addressCtrl.text = user?.address ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveInfo() async {
    final user = context.read<AuthProvider>().user;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Name cannot be empty', error: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter a valid email', error: true);
      return;
    }

    // Only send fields that changed
    final updates = <String, String>{};
    if (name != user?.name) updates['name'] = name;
    if (email != user?.email) updates['email'] = email;
    if (phone != (user?.phone ?? '')) updates['phone'] = phone;
    if (address != (user?.address ?? '')) updates['address'] = address;

    if (updates.isEmpty) {
      _showSnack('No changes to save');
      return;
    }

    setState(() => _savingInfo = true);
    final error = await context.read<AuthProvider>().updateProfile(
          name: updates['name'],
          email: updates['email'],
          phone: updates['phone'],
          address: updates['address'],
        );
    setState(() => _savingInfo = false);

    if (error != null) {
      _showSnack(error, error: true);
    } else {
      _showSnack('Profile updated successfully ✓');
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showSnack('All password fields are required', error: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('New password must be at least 6 characters', error: true);
      return;
    }
    if (newPass != confirm) {
      _showSnack('New passwords do not match', error: true);
      return;
    }

    setState(() => _savingPass = true);
    final error = await context.read<AuthProvider>().changePassword(current, newPass);
    setState(() => _savingPass = false);

    if (error != null) {
      _showSnack(error, error: true);
    } else {
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _showSnack('Password changed successfully ✓');
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initial = (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppTheme.teal,
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(user?.name ?? '',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.role ?? '').toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Personal Info Section ──────────────────────────────
            _SectionTitle(title: 'Personal Info', icon: Icons.person_outline),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _Field(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      inputType: TextInputType.name,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      inputType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _phoneCtrl,
                      label: 'Mobile Number',
                      icon: Icons.phone_outlined,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _addressCtrl,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _savingInfo ? null : _saveInfo,
                        child: _savingInfo
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Change Password Section ────────────────────────────
            _SectionTitle(title: 'Change Password', icon: Icons.lock_outline),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PasswordField(
                      controller: _currentPassCtrl,
                      label: 'Current Password',
                      obscure: _obscureCurrent,
                      onToggle: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: _newPassCtrl,
                      label: 'New Password',
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: _confirmPassCtrl,
                      label: 'Confirm New Password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _savingPass ? null : _changePassword,
                        child: _savingPass
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Change Password',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.navy),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
                letterSpacing: 0.3)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? inputType;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.inputType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
