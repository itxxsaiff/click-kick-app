import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../widgets/password_change_layout.dart';

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
  bool _submitted = false;

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
    setState(() => _submitted = true);
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
      _show(context.tr('Password updated successfully.'));
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
    return PasswordChangeLayout(
      title: context.tr('Change Password'),
      currentController: _current,
      newController: _newPass,
      confirmController: _confirm,
      currentObscure: _obscureCurrent,
      newObscure: _obscureNew,
      confirmObscure: _obscureConfirm,
      onToggleCurrent: () =>
          setState(() => _obscureCurrent = !_obscureCurrent),
      onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
      onToggleConfirm: () =>
          setState(() => _obscureConfirm = !_obscureConfirm),
      onSubmit: _changePassword,
      saving: _saving,
      currentError: _submitted && _current.text.trim().isEmpty
          ? context.tr('Current password is required.')
          : null,
      newError: _submitted
          ? (_newPass.text.trim().isEmpty
              ? context.tr('New password is required.')
              : _newPass.text.trim().length < 6
                  ? context.tr('New password must be at least 6 characters.')
                  : null)
          : null,
      confirmError: _submitted
          ? (_confirm.text.trim().isEmpty
              ? context.tr('Confirm password is required.')
              : _newPass.text.trim() != _confirm.text.trim()
                  ? context.tr('Passwords do not match.')
                  : null)
          : null,
    );
  }
}
