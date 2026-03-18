import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phoneCode = TextEditingController(text: '+1');
  final _phoneNumber = TextEditingController();
  final _currentPassword = TextEditingController();
  String _phoneIso = 'US';
  bool _saving = false;
  bool _loading = true;
  bool _obscureCurrentPassword = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phoneCode.dispose();
    _phoneNumber.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? <String, dynamic>{};
    _name.text = (data['displayName'] ?? user.displayName ?? '').toString();
    _email.text = (data['email'] ?? user.email ?? '').toString();
    _phoneCode.text = (data['phoneCountryCode'] ?? '+1').toString();
    _phoneNumber.text = (data['phoneNumber'] ?? '').toString();
    _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final newEmail = _email.text.trim();
      final willUpdateEmail =
          newEmail.isNotEmpty && newEmail != (user.email ?? '');
      if (willUpdateEmail) {
        if (_currentPassword.text.trim().isEmpty) {
          _show(context.tr('Current password is required.'));
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: (user.email ?? '').trim(),
          password: _currentPassword.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.verifyBeforeUpdateEmail(newEmail);
      }
      await user.updateDisplayName(_name.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _name.text.trim(),
        'phoneCountryCode': _phoneCode.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumber.text.trim(),
        'phoneE164': '${_phoneCode.text.trim()}${_phoneNumber.text.trim()}',
        if (willUpdateEmail) 'pendingEmail': newEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      _show(
        willUpdateEmail
            ? context.tr(
                'Verification email sent. Confirm it to complete email change.',
              )
            : context.tr('Profile updated.'),
      );
    } catch (e) {
      _show(context.tr('Update failed.'));
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
        title: Text(context.tr('Profile')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: context.tr('Full name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _email,
                        decoration: InputDecoration(
                          labelText: context.tr('Email'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: true,
                                  onSelect: (country) {
                                    setState(() {
                                      _phoneCode.text =
                                          '+${country.phoneCode}';
                                      _phoneIso = country.countryCode;
                                    });
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: context.tr('Code'),
                                ),
                                child: Text(
                                  '$_phoneIso ${_phoneCode.text}',
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 7,
                            child: TextField(
                              controller: _phoneNumber,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: context.tr('Phone number'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentPassword,
                        obscureText: _obscureCurrentPassword,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Current Password (for email change)',
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureCurrentPassword =
                                  !_obscureCurrentPassword,
                            ),
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      GradientButton(
                        label: _saving
                            ? context.tr('Saving...')
                            : context.tr('Update Profile'),
                        onPressed: _saving ? () {} : _save,
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
