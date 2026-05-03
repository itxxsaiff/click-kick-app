import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/settings_action_tile.dart';
import '../admin/admin_videos_screen.dart';
import '../shared/legal_center_screen.dart';
import '../shared/support_chat_screen.dart';
import '../auth/login_screen.dart';

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
      default:
        return context.tr('Profile');
    }
  }

  IconData _icon() {
    switch (_index) {
      case 0:
        return Icons.dashboard_customize;
      default:
        return Icons.person;
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
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      _EmployeeDashboardTab(displayName: widget.displayName),
                      _EmployeeProfileTab(displayName: widget.displayName),
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

class _EmployeeProfileTab extends StatelessWidget {
  const _EmployeeProfileTab({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(context.tr('Please login.')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name =
            (data['displayName'] ?? user.displayName ?? displayName).toString();
        final email = (data['email'] ?? user.email ?? '').toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.hotPink,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionTile(
              icon: Icons.badge_outlined,
              title: context.tr('Profile Info'),
              subtitle: context.tr('View your account information.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _EmployeeProfileInfoScreen(user: user),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.edit_outlined,
              title: context.tr('Profile Update'),
              subtitle: context.tr('Update your name, email, and phone.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _EmployeeProfileUpdateScreen(
                      user: user,
                      displayName: displayName,
                    ),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.lock_outline,
              title: context.tr('Change Password'),
              subtitle: context.tr('Update your account password securely.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _EmployeeSecurityScreen(),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.language_outlined,
              title: context.tr('Language'),
              subtitle: context.tr('Choose language'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LanguageSelectionScreen(),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.support_agent_outlined,
              title: context.tr('Support'),
              subtitle: context.tr('Chat with support team.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatScreen(
                      threadId: user.uid,
                      title: context.tr('Support'),
                      subtitle: user.email,
                    ),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.privacy_tip_outlined,
              title: context.tr('Legal & Privacy'),
              subtitle: context.tr('Terms, guidelines, and privacy policy.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalCenterScreen(),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.delete_outline_rounded,
              title: context.tr('Delete Account'),
              subtitle: context.tr('Permanently remove your account.'),
              isDanger: true,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(context.tr('Delete Account')),
                    content: Text(
                      context.tr(
                        'Are you sure you want to delete your account? This action cannot be undone.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(context.tr('Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.hotPink,
                        ),
                        child: Text(context.tr('Delete')),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await AuthService().deleteCurrentAccount();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Account deleted successfully.')),
                    ),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (_) => false,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  final message = e.toString().contains('requires-recent-login')
                      ? context.tr(
                          'Please login again before deleting your account.',
                        )
                      : context.tr(
                          'Unable to delete account right now. Please try again.',
                        );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              },
            ),
            SettingsActionTile(
              icon: Icons.logout,
              title: context.tr('Logout'),
              subtitle: context.tr('Sign out from your account.'),
              isDanger: true,
              onTap: () async {
                await AuthService().signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              },
            ),
          ],
        );
      },
    );
  }
}

class _EmployeeProfileInfoScreen extends StatelessWidget {
  const _EmployeeProfileInfoScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profile Info'))),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final rows = <MapEntry<String, String>>[
            MapEntry(context.tr('Full Name'), (data['displayName'] ?? user.displayName ?? '').toString()),
            MapEntry(context.tr('Email'), (data['email'] ?? user.email ?? '').toString()),
            MapEntry(context.tr('Phone number'), '${(data['phoneCountryCode'] ?? '').toString()} ${(data['phoneNumber'] ?? '').toString()}'.trim()),
          ];
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.key, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(row.value.isEmpty ? '-' : row.value, style: const TextStyle(color: AppColors.textLight, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmployeeProfileUpdateScreen extends StatefulWidget {
  const _EmployeeProfileUpdateScreen({required this.user, required this.displayName});

  final User user;
  final String displayName;

  @override
  State<_EmployeeProfileUpdateScreen> createState() => _EmployeeProfileUpdateScreenState();
}

class _EmployeeProfileUpdateScreenState extends State<_EmployeeProfileUpdateScreen> {
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
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    _name.text = (data['displayName'] ?? widget.user.displayName ?? widget.displayName).toString();
    _email.text = (data['email'] ?? widget.user.email ?? '').toString();
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
      final willUpdateEmail = newEmail.isNotEmpty && newEmail != (user.email ?? '');
      if (willUpdateEmail) {
        if (_currentPassword.text.trim().isEmpty) {
          _showEmployeeMessage(context, context.tr('Current password is required.'));
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

      _showEmployeeMessage(
        context,
        willUpdateEmail
            ? context.tr('Verification email sent. Confirm it to complete email change.')
            : context.tr('Profile updated.'),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showEmployeeMessage(context, context.tr('Current password is incorrect.'));
      } else {
        _showEmployeeMessage(context, context.tr('Update failed.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profile Update'))),
      body: ListView(
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
                TextField(controller: _name, decoration: InputDecoration(labelText: context.tr('Full Name'))),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: InputDecoration(labelText: context.tr('Email'))),
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
                          decoration: InputDecoration(labelText: context.tr('Code')),
                          child: Text('$_phoneIso ${_phoneCode.text}', style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: TextField(
                        controller: _phoneNumber,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: context.tr('Phone number')),
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
                      onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                      icon: Icon(_obscureCurrentPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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
        ],
      ),
    );
  }
}

void _showEmployeeMessage(BuildContext context, String message) {
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

class _EmployeeSecurityScreen extends StatefulWidget {
  const _EmployeeSecurityScreen();

  @override
  State<_EmployeeSecurityScreen> createState() => _EmployeeSecurityTabState();
}

class _EmployeeSecurityTabState extends State<_EmployeeSecurityScreen> {
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
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScreenHeader(title: context.tr('Change Password')),
                const SizedBox(height: 16),
                _FormCard(
                  child: Column(
                    children: [
                      _PasswordField(
                        controller: _current,
                        hintText: context.tr('Current Password'),
                        obscureText: _obscureCurrent,
                        onToggle: () => setState(
                          () => _obscureCurrent = !_obscureCurrent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: _newPass,
                        hintText: context.tr('New Password'),
                        obscureText: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 12),
                      _PasswordField(
                        controller: _confirm,
                        hintText: context.tr('Confirm Password'),
                        obscureText: _obscureConfirm,
                        onToggle: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
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
