import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import 'contests/admin_contests_screen.dart';
import 'profile/admin_profile_screen.dart';
import 'profile/admin_security_screen.dart';
import '../../services/auth_service.dart';
import 'admin_participants_screen.dart';
import 'admin_visitors_screen.dart';
import 'admin_videos_screen.dart';
import 'feed_videos/admin_feed_videos_screen.dart';
import 'news/admin_news_screen.dart';
import 'admin_employees_screen.dart';
import 'ads/admin_ads_screen.dart';
import 'payments/admin_invoices_screen.dart';
import 'payments/admin_payments_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.cardSoft,
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.hotPink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Admin Console'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const LanguageMenuButton(compact: true),
                      IconButton(
                        onPressed: () async {
                          await AuthService().signOut();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (_) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.05,
                      children: [
                        _AdminTile(
                          title: context.tr('Contests'),
                          subtitle: context.tr('Create & manage'),
                          icon: Icons.emoji_events,
                          accent: AppColors.hotPink,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminContestsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Feed Videos'),
                          subtitle: context.tr('Public feed clips'),
                          icon: Icons.video_collection_outlined,
                          accent: const Color(0xFF65E8FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminFeedVideosScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('News'),
                          subtitle: context.tr('Announcements'),
                          icon: Icons.campaign,
                          accent: AppColors.magenta,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminNewsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Sponsorships'),
                          subtitle: context.tr('Applications & settings'),
                          icon: Icons.inventory_2,
                          accent: AppColors.hotPink,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminAdsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Participants'),
                          subtitle: context.tr('Creators list'),
                          icon: Icons.groups,
                          accent: AppColors.neonGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminParticipantsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Employees'),
                          subtitle: context.tr('Manage moderators'),
                          icon: Icons.badge_outlined,
                          accent: const Color(0xFF65E8FF),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminEmployeesScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Videos'),
                          subtitle: context.tr('Approve/reject'),
                          icon: Icons.video_library,
                          accent: AppColors.sunset,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminVideosScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Visitors'),
                          subtitle: context.tr('Voters & stats'),
                          icon: Icons.visibility,
                          accent: AppColors.magenta,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminVisitorsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Invoices'),
                          subtitle: context.tr('Billing docs'),
                          icon: Icons.receipt_long,
                          accent: AppColors.gold,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminInvoicesScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Payments'),
                          subtitle: context.tr('Stripe status'),
                          icon: Icons.credit_card,
                          accent: AppColors.hotPink,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminPaymentsScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Profile'),
                          subtitle: context.tr('Update info'),
                          icon: Icons.person,
                          accent: AppColors.neonGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminProfileScreen(),
                              ),
                            );
                          },
                        ),
                        _AdminTile(
                          title: context.tr('Security'),
                          subtitle: context.tr('Change password'),
                          icon: Icons.lock,
                          accent: AppColors.sunset,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminSecurityScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
            right: -60,
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
          colors: [color.withOpacity(0.55), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}
