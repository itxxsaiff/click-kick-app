import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/settings_action_tile.dart';
import '../auth/login_screen.dart';
import '../public/public_feed_screen.dart' show PublicUserProfileUpdateScreen;
import '../shared/blocked_users_screen.dart';
import '../shared/legal_center_screen.dart';
import '../shared/support_chat_screen.dart';

/// Settings page. These are the options that used to live directly on the
/// Profile tab (edit profile, support, legal, blocked users, delete account,
/// logout), moved here unchanged.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed != true) return;
    try {
      await AuthService().deleteCurrentAccount();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Your account has been permanently deleted.'),
          ),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e.toString().contains('requires-recent-login')
          ? context.tr('Please login again before deleting your account.')
          : context.tr('Unable to delete account right now. Please try again.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Settings')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: user == null
                ? Center(child: Text(context.tr('Please login.')))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SettingsActionTile(
                        icon: Icons.person_outline,
                        title: context.tr('Profile'),
                        subtitle: context.tr(
                          'Manage profile, language, and security in one place.',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PublicUserProfileUpdateScreen(user: user),
                          ),
                        ),
                      ),
                      SettingsActionTile(
                        icon: Icons.support_agent_outlined,
                        title: context.tr('Support'),
                        subtitle: context.tr('Chat with support team.'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupportChatScreen(
                              threadId: user.uid,
                              title: context.tr('Support'),
                              subtitle: user.email,
                            ),
                          ),
                        ),
                      ),
                      SettingsActionTile(
                        icon: Icons.privacy_tip_outlined,
                        title: context.tr('Legal & Privacy'),
                        subtitle: context.tr(
                          'Terms, guidelines, and privacy policy.',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalCenterScreen(),
                          ),
                        ),
                      ),
                      SettingsActionTile(
                        icon: Icons.block,
                        title: context.tr('Blocked Users'),
                        subtitle: context.tr(
                          'Manage participants you have blocked.',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BlockedUsersScreen(),
                          ),
                        ),
                      ),
                      SettingsActionTile(
                        icon: Icons.delete_outline_rounded,
                        title: context.tr('Delete Account'),
                        subtitle: context.tr(
                          'Permanently remove your account.',
                        ),
                        isDanger: true,
                        onTap: () => _deleteAccount(context),
                      ),
                      SettingsActionTile(
                        icon: Icons.logout,
                        title: context.tr('Logout'),
                        subtitle: context.tr('Sign out from your account.'),
                        isDanger: true,
                        onTap: () async {
                          await AuthService().signOut();
                          if (!context.mounted) return;
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/',
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
