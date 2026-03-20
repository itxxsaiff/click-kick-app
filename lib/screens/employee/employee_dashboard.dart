import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../admin/admin_videos_screen.dart';
import '../shared/legal_center_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key, required this.displayName});

  final String displayName;

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  int _index = 0;

  String _title(BuildContext context) {
    switch (_index) {
      case 0:
        return context.tr('Dashboard');
      case 1:
        return context.tr('Profile');
      default:
        return context.tr('Security');
    }
  }

  IconData _icon() {
    switch (_index) {
      case 0:
        return Icons.dashboard_customize;
      case 1:
        return Icons.person;
      default:
        return Icons.lock;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.cardSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon(), color: AppColors.hotPink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title(context),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              widget.displayName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const LanguageMenuButton(compact: true),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _EmployeeDashboardTab(displayName: widget.displayName),
                      _EmployeeProfileTab(displayName: widget.displayName),
                      const _EmployeeSecurityTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x221B1033), Color(0xCC130B25)],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1847), Color(0xFF1C1232)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border.withOpacity(0.9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (v) => setState(() => _index = v),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.hotPink,
              unselectedItemColor: AppColors.textMuted.withOpacity(0.95),
              selectedFontSize: 13,
              unselectedFontSize: 12,
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard_customize),
                  label: context.tr('Dashboard'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: context.tr('Profile'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.lock_outline),
                  activeIcon: const Icon(Icons.lock),
                  label: context.tr('Security'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeDashboardTab extends StatelessWidget {
  const _EmployeeDashboardTab({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final contestsStream = FirebaseFirestore.instance
        .collection('contests')
        .where('contestAdminId', isEqualTo: uid)
        .snapshots();
    final submissionsStream = FirebaseFirestore.instance
        .collectionGroup('submissions')
        .where('contestAdminId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: contestsStream,
      builder: (context, contestSnap) {
        if (!contestSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contests = contestSnap.data!.docs;
        final now = DateTime.now();
        int active = 0;
        int completed = 0;
        for (final doc in contests) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final votingEnd =
              (data['votingEnd'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          if (status == 'live') active++;
          if (status == 'completed' || votingEnd.isBefore(now)) {
            completed++;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: submissionsStream,
          builder: (context, submissionsSnap) {
            final participantVideos = submissionsSnap.data?.docs.length ?? 0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 900
                        ? 4
                        : width >= 600
                        ? 4
                        : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: width >= 900 ? 2.1 : 1.35,
                      children: [
                        _StatTile(
                          label: context.tr('Assigned Contests'),
                          value: contests.length.toString(),
                          color: AppColors.hotPink,
                          icon: Icons.assignment_turned_in,
                        ),
                        _StatTile(
                          label: context.tr('Active'),
                          value: active.toString(),
                          color: AppColors.neonGreen,
                          icon: Icons.bolt,
                        ),
                        _StatTile(
                          label: context.tr('Completed'),
                          value: completed.toString(),
                          color: AppColors.sunset,
                          icon: Icons.task_alt,
                        ),
                        _StatTile(
                          label: context.tr('Participants Videos'),
                          value: participantVideos.toString(),
                          color: const Color(0xFF5AB4FF),
                          icon: Icons.video_collection,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('Assigned Contests'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (contests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      context.tr(
                        'No contests assigned yet. Please wait for admin assignment.',
                      ),
                    ),
                  )
                else
                  ...contests.map((doc) {
                    final data = doc.data();
                    final title = (data['title'] ?? '').toString();
                    final description = (data['description'] ?? '').toString();
                    final status = (data['status'] ?? 'contest_created')
                        .toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.emoji_events,
                                color: AppColors.hotPink,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminVideosScreen(
                                      contestIdFilter: doc.id,
                                      customTitle:
                                          '${context.tr('Videos Moderation')}: $title',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.video_library),
                              label: Text(context.tr('Moderate Videos')),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'live':
        return AppColors.neonGreen;
      case 'completed':
        return AppColors.sunset;
      case 'contest_created':
        return AppColors.hotPink;
      default:
        return AppColors.textMuted;
    }
  }
}

class _EmployeeProfileTab extends StatefulWidget {
  const _EmployeeProfileTab({required this.displayName});

  final String displayName;

  @override
  State<_EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends State<_EmployeeProfileTab> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phoneCode = TextEditingController(text: '+1');
  final _phoneNumber = TextEditingController();
  final _currentPassword = TextEditingController();
  String _phoneIso = 'US';
  bool _loading = true;
  bool _saving = false;
  bool _obscureCurrentPassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    _name.text = (data['displayName'] ?? user.displayName ?? widget.displayName)
        .toString();
    _email.text = (data['email'] ?? user.email ?? '').toString();
    _phoneCode.text = (data['phoneCountryCode'] ?? '+1').toString();
    _phoneNumber.text = (data['phoneNumber'] ?? '').toString();
    _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    if (mounted) setState(() => _loading = false);
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
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context.tr('Current password is incorrect.'));
      } else {
        _show(context.tr('Update failed.'));
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: context.tr('Full Name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: InputDecoration(labelText: context.tr('Email')),
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
                              _phoneCode.text = '+${country.phoneCode}';
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
                  labelText: context.tr('Current Password (for email change)'),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _saving ? context.tr('Saving...') : context.tr('Update Profile'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalCenterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(context.tr('Legal & Privacy')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            icon: const Icon(Icons.logout),
            label: Text(context.tr('Logout')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93A63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeSecurityTab extends StatefulWidget {
  const _EmployeeSecurityTab();

  @override
  State<_EmployeeSecurityTab> createState() => _EmployeeSecurityTabState();
}

class _EmployeeSecurityTabState extends State<_EmployeeSecurityTab> {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
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
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _saving
                        ? context.tr('Updating...')
                        : context.tr('Update Password'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 160,
            right: -80,
            child: _GlowOrb(size: 220, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.55), color.withOpacity(0)],
        ),
      ),
    );
  }
}
