import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    if (_current.text.trim().isEmpty) {
      _show(context.tr('Current password is required.'));
      return;
    }
    if (_newPass.text.trim().isEmpty) {
      _show(context.tr('New password is required.'));
      return;
    }
    if (_newPass.text.trim().length < 6) {
      _show(context.tr('New password must be at least 6 characters.'));
      return;
    }
    if (_newPass.text.trim() != _confirm.text.trim()) {
      _show(context.tr('Passwords do not match.'));
      return;
    }
    setState(() => _saving = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _current.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPass.text.trim());
      _show(context.tr('Password updated.'));
      _current.clear();
      _newPass.clear();
      _confirm.clear();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context.tr('Current password is incorrect.'));
      } else if (e.code == 'weak-password') {
        _show(context.tr('New password is too weak.'));
      } else if (e.code == 'requires-recent-login') {
        _show(context.tr('Please login again and retry password update.'));
      } else {
        _show('Password update failed (${e.code}).');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Security')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _current,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: context.tr('Current password'),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPass,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: context.tr('New password'),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: context.tr('Confirm new password'),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: _saving
                      ? context.tr('Updating...')
                      : context.tr('Update Password'),
                  onPressed: _saving ? () {} : _changePassword,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [AppColors.cosmicPurple, AppColors.deepSpace],
        ),
      ),
    );
  }
}
