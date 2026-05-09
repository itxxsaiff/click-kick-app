import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'admin_video_reports_screen.dart';
import 'admin_contest_draw_winners_screen.dart';
import 'admin_support_screen.dart';
import 'payments/admin_invoices_screen.dart';
import 'payments/admin_payments_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.displayName});

  final String displayName;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<_AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_AdminDashboardStats> _loadStats() async {
    final firestore = FirebaseFirestore.instance;
    final usersFuture = firestore.collection('users').get();
    final contestsFuture = firestore.collection('contests').get();
    final ticketsFuture = firestore.collection('support_threads').get();
    final paymentsFuture = firestore.collection('payments').get();

    final results = await Future.wait([
      usersFuture,
      contestsFuture,
      ticketsFuture,
      paymentsFuture,
    ]);

    final users = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final contests = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final tickets = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final payments = results[3] as QuerySnapshot<Map<String, dynamic>>;

    int employees = 0;
    int participants = 0;
    int sponsors = 0;
    int activeUsers = 0;
    final recentUsers = <_RecentUserRow>[];
    final userTimeline = List<int>.filled(7, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final doc in users.docs) {
      final data = doc.data();
      final role = (data['role'] ?? 'user').toString().toLowerCase();
      final accountStatus = (data['accountStatus'] ?? 'active')
          .toString()
          .toLowerCase();
      if (accountStatus == 'active') activeUsers += 1;

      if (role == 'employee' || role == 'admin' || role == 'moderator') {
        employees += 1;
      } else if (role == 'sponsor' || role == 'business') {
        sponsors += 1;
      } else {
        participants += 1;
      }

      final createdAt = _dateFromAny(
        data['createdAt'] ?? data['updatedAt'] ?? data['joinedAt'],
      );
      if (createdAt != null) {
        final createdDay = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );
        final diff = today.difference(createdDay).inDays;
        if (diff >= 0 && diff < 7) {
          userTimeline[6 - diff] += 1;
        }
      }

      recentUsers.add(
        _RecentUserRow(
          name:
              (data['displayName'] ??
                      data['companyName'] ??
                      data['email'] ??
                      'User')
                  .toString(),
          role: role,
          email: (data['email'] ?? '').toString(),
          status: accountStatus,
          createdAt: createdAt,
        ),
      );
    }

    recentUsers.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    final openTickets = tickets.docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? 'open').toString().toLowerCase();
      return status == 'open' || status == 'pending' || status.isEmpty;
    }).length;

    double revenue = 0;
    int failedPayments = 0;
    int unpaidInvoices = 0;
    for (final doc in payments.docs) {
      final data = doc.data();
      final status = (data['paymentStatus'] ?? data['status'] ?? '')
          .toString()
          .toLowerCase();
      final amount =
          (data['totalAmount'] ?? data['amount'] ?? data['applicationFee'] ?? 0)
              as num;
      if (status == 'paid' || status == 'succeeded' || status == 'success') {
        revenue += amount.toDouble();
      } else if (status == 'failed') {
        failedPayments += 1;
      } else if (status == 'unpaid') {
        unpaidInvoices += 1;
      }
    }

    final activeContests = contests.docs.where((doc) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      return status == 'live' || status == 'active';
    }).length;

    return _AdminDashboardStats(
      totalUsers: users.size,
      totalContests: contests.size,
      openTickets: openTickets,
      revenue: revenue,
      activeContests: activeContests,
      unpaidInvoices: unpaidInvoices,
      failedPayments: failedPayments,
      totalEmployees: employees,
      totalParticipants: participants,
      totalSponsors: sponsors,
      activeUsers: activeUsers,
      userTimeline: userTimeline,
      recentUsers: recentUsers.take(6).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = [
      _AdminModuleItem(
        title: context.tr('Contests'),
        subtitle: context.tr('Create & manage contests'),
        icon: Icons.emoji_events,
        accent: AppColors.sunset,
        badge: context.tr('Active'),
        badgeValueFuture: _statsFuture.then((stats) => stats.activeContests),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminContestsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Feed Videos'),
        subtitle: context.tr('Manage public feed clips'),
        icon: Icons.video_collection_outlined,
        accent: const Color(0xFF65E8FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFeedVideosScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Support'),
        subtitle: context.tr('User help messages'),
        icon: Icons.support_agent_outlined,
        accent: AppColors.neonGreen,
        badge: context.tr('Open'),
        badgeValueFuture: _statsFuture.then((stats) => stats.openTickets),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('News'),
        subtitle: context.tr('Announcements & updates'),
        icon: Icons.campaign,
        accent: AppColors.magenta,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminNewsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Visitors'),
        subtitle: context.tr('Voters & statistics overview'),
        icon: Icons.visibility,
        accent: AppColors.magenta,
        badgeValue: '1,024',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminVisitorsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Sponsorships'),
        subtitle: context.tr('Applications & settings'),
        icon: Icons.inventory_2,
        accent: AppColors.hotPink,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAdsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Invoices'),
        subtitle: context.tr('Billing documents & history'),
        icon: Icons.receipt_long,
        accent: AppColors.gold,
        badge: context.tr('Unpaid'),
        badgeValueFuture: _statsFuture.then((stats) => stats.unpaidInvoices),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminInvoicesScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Participants'),
        subtitle: context.tr('Creators list & details'),
        icon: Icons.groups,
        accent: AppColors.neonGreen,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminParticipantsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Payments'),
        subtitle: context.tr('Stripe payments status'),
        icon: Icons.credit_card,
        accent: AppColors.hotPink,
        badge: context.tr('Failed'),
        badgeValueFuture: _statsFuture.then((stats) => stats.failedPayments),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Employees'),
        subtitle: context.tr('Manage admins & moderators'),
        icon: Icons.badge_outlined,
        accent: const Color(0xFF65E8FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Language'),
        subtitle: context.tr('Change app language'),
        icon: Icons.language,
        accent: const Color(0xFF65E8FF),
        badgeValue: '2',
        badge: context.tr('Languages'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Videos'),
        subtitle: context.tr('Approve / reject submissions'),
        icon: Icons.video_library,
        accent: AppColors.sunset,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminVideosScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Profile'),
        subtitle: context.tr('Update admin information'),
        icon: Icons.person,
        accent: AppColors.neonGreen,
        badgeValue: context.tr('Updated'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Video Reports'),
        subtitle: context.tr('Review flags & reports'),
        icon: Icons.flag_outlined,
        accent: const Color(0xFF65E8FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminVideoReportsScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Security'),
        subtitle: context.tr('Change password'),
        icon: Icons.lock,
        accent: AppColors.sunset,
        badgeValue: context.tr('Secure'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminSecurityScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Important Alerts'),
        subtitle: context.tr('You have open tickets and pending payments'),
        icon: Icons.privacy_tip_outlined,
        accent: const Color(0xFF8D5CF6),
        trailingLabel: context.tr('View All'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminSupportScreen()),
          );
        },
      ),
      _AdminModuleItem(
        title: context.tr('Contest Draw Winners'),
        subtitle: context.tr('Lucky draw results'),
        icon: Icons.card_giftcard_rounded,
        accent: AppColors.gold,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminContestDrawWinnersScreen(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: FutureBuilder<_AdminDashboardStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? const _AdminDashboardStats();
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _statsFuture = _loadStats();
                      });
                      await _statsFuture;
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.card.withOpacity(0.94),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.18),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSoft,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings,
                                      color: AppColors.hotPink,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('Admin Console'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: AppColors.textMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _HeaderIconButton(
                                        icon: Icons.logout,
                                        onTap: () async {
                                          await AuthService().signOut();
                                          if (context.mounted) {
                                            Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              '/',
                                              (_) => false,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final statCols = width > 420 ? 2 : 1;
                                final statRatio = width > 860
                                    ? 1.55
                                    : width > 560
                                    ? 1.45
                                    : 1.95;
                                return GridView.count(
                                  crossAxisCount: statCols,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: statRatio,
                                  children: [
                                    _DashboardStatCard(
                                      icon: Icons.groups_rounded,
                                      accent: AppColors.hotPink,
                                      value: stats.totalUsers.toString(),
                                      label: context.tr('Total Users'),
                                      hint: context.tr(
                                        'All registered accounts',
                                      ),
                                      footer:
                                          '${stats.activeUsers} ${context.tr('active')}',
                                    ),
                                    _DashboardStatCard(
                                      icon: Icons.badge_outlined,
                                      accent: const Color(0xFF69E8FF),
                                      value: stats.totalEmployees.toString(),
                                      label: context.tr('Employees'),
                                      hint: context.tr('Admins & moderators'),
                                      footer:
                                          '${stats.totalSponsors} ${context.tr('sponsors')}',
                                    ),
                                    _DashboardStatCard(
                                      icon: Icons.emoji_events_outlined,
                                      accent: AppColors.sunset,
                                      value: stats.totalContests.toString(),
                                      label: context.tr('Contests'),
                                      hint: context.tr('Created contests'),
                                      footer:
                                          '${stats.activeContests} ${context.tr('live')}',
                                    ),
                                    _DashboardStatCard(
                                      icon: Icons.support_agent_outlined,
                                      accent: AppColors.neonGreen,
                                      value: stats.openTickets.toString(),
                                      label: context.tr('Open Tickets'),
                                      hint: context.tr('Need attention'),
                                      footer:
                                          '\$${stats.revenue.toStringAsFixed(0)} ${context.tr('revenue')}',
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth > 780;
                                return GridView.count(
                                  crossAxisCount: wide ? 2 : 1,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: wide ? 1.7 : 1.18,
                                  children: [
                                    _AnalyticsPanel(
                                      title: context.tr('Visitors Overview'),
                                      actionLabel: context.tr('Last 7 days'),
                                      child: _LineOverviewChart(
                                        values: stats.userTimeline,
                                      ),
                                    ),
                                    _AnalyticsPanel(
                                      title: context.tr('Audience Mix'),
                                      actionLabel: context.tr('Live split'),
                                      child: _RoleBreakdown(
                                        participants: stats.totalParticipants,
                                        employees: stats.totalEmployees,
                                        sponsors: stats.totalSponsors,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth > 780;
                                return GridView.count(
                                  crossAxisCount: wide ? 2 : 1,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: wide ? 1.95 : 1.08,
                                  children: [
                                    _AnalyticsPanel(
                                      title: context.tr('Recent Users'),
                                      actionLabel: context.tr(
                                        'Latest accounts',
                                      ),
                                      child: _RecentUsersList(
                                        rows: stats.recentUsers,
                                      ),
                                    ),
                                    _AnalyticsPanel(
                                      title: context.tr('Quick Summary'),
                                      actionLabel: context.tr('Snapshot'),
                                      child: _QuickSummaryGrid(stats: stats),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final crossAxisCount = width > 1180
                                    ? 3
                                    : width > 720
                                    ? 2
                                    : 1;
                                final ratio = width > 1180
                                    ? 2.75
                                    : width > 720
                                    ? 2.35
                                    : 3.3;
                                return GridView.builder(
                                  itemCount: modules.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: ratio,
                                      ),
                                  itemBuilder: (context, index) {
                                    return _AdminModuleCard(
                                      item: modules[index],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminModuleItem {
  const _AdminModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
    this.badgeValue,
    this.badgeValueFuture,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final String? badgeValue;
  final Future<Object?>? badgeValueFuture;
  final String? trailingLabel;
}

class _AdminModuleCard extends StatelessWidget {
  const _AdminModuleCard({required this.item});

  final _AdminModuleItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF26173F), Color(0xFF201333)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (item.badge != null ||
                          item.badgeValue != null ||
                          item.badgeValueFuture != null)
                        _AdminModuleBadge(item: item),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.28),
                  ),
                ],
              ),
            ),
            if ((item.trailingLabel ?? '').isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                item.trailingLabel!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AdminModuleBadge extends StatelessWidget {
  const _AdminModuleBadge({required this.item});

  final _AdminModuleItem item;

  @override
  Widget build(BuildContext context) {
    final directValue = item.badgeValue;
    if (directValue != null) {
      return _BadgePill(
        label: item.badge == null ? directValue : '$directValue ${item.badge}',
        color: item.accent,
      );
    }
    if (item.badgeValueFuture != null) {
      return FutureBuilder<Object?>(
        future: item.badgeValueFuture,
        builder: (context, snapshot) {
          final value = snapshot.data?.toString() ?? '--';
          return _BadgePill(
            label: item.badge == null ? value : '$value ${item.badge}',
            color: item.accent,
          );
        },
      );
    }
    return _BadgePill(label: item.badge ?? '', color: item.accent);
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    required this.hint,
    this.footer,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final String hint;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if ((footer ?? '').isNotEmpty) ...[
            const Spacer(),
            Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent.withOpacity(0.95),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.title,
    required this.child,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if ((actionLabel ?? '').isNotEmpty)
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LineOverviewChart extends StatelessWidget {
  const _LineOverviewChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = [
      '2 May',
      '3 May',
      '4 May',
      '5 May',
      '6 May',
      '7 May',
      '8 May',
    ];
    final safeValues = values.isEmpty ? List<int>.filled(7, 0) : values;
    final maxValue = (safeValues.reduce(
      (a, b) => a > b ? a : b,
    )).clamp(1, 999999);

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: _LineChartPainter(
              values: safeValues,
              lineColor: AppColors.hotPink,
              fillColor: const Color(0x33F64AC9),
              gridColor: Colors.white.withOpacity(0.08),
              maxValue: maxValue.toDouble(),
            ),
            child: Container(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == labels.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoleBreakdown extends StatelessWidget {
  const _RoleBreakdown({
    required this.participants,
    required this.employees,
    required this.sponsors,
  });

  final int participants;
  final int employees;
  final int sponsors;

  @override
  Widget build(BuildContext context) {
    final segments = [
      _PieSegment(
        value: participants.toDouble(),
        color: AppColors.hotPink,
        label: context.tr('Participants'),
      ),
      _PieSegment(
        value: employees.toDouble(),
        color: const Color(0xFF69E8FF),
        label: context.tr('Employees'),
      ),
      _PieSegment(
        value: sponsors.toDouble(),
        color: AppColors.sunset,
        label: context.tr('Sponsors'),
      ),
    ];
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _DonutChartPainter(segments: segments, total: total),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      total.toInt().toString(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      context.tr('Accounts'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: segments
                .map(
                  (segment) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: segment.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            segment.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          segment.value.toInt().toString(),
                          style: TextStyle(
                            color: segment.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _QuickSummaryGrid extends StatelessWidget {
  const _QuickSummaryGrid({required this.stats});

  final _AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '${stats.totalParticipants}',
        context.tr('Participants'),
        AppColors.hotPink,
      ),
      (
        '${stats.totalEmployees}',
        context.tr('Employees'),
        const Color(0xFF69E8FF),
      ),
      ('${stats.totalSponsors}', context.tr('Sponsors'), AppColors.sunset),
      (
        '${stats.unpaidInvoices}',
        context.tr('Unpaid invoices'),
        AppColors.gold,
      ),
      (
        '${stats.failedPayments}',
        context.tr('Failed payments'),
        const Color(0xFFD85A5A),
      ),
      (
        '${stats.activeContests}',
        context.tr('Live contests'),
        AppColors.neonGreen,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardSoft.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.$1,
                style: TextStyle(
                  color: item.$3,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.$2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentUsersList extends StatelessWidget {
  const _RecentUsersList({required this.rows});

  final List<_RecentUserRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No recent users',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.cardSoft,
                    child: Text(
                      _initialsFromName(row.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.email.isEmpty ? row.role : row.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _BadgePill(
                        label: row.status,
                        color: row.status == 'active'
                            ? AppColors.neonGreen
                            : AppColors.sunset,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortDate(row.createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.cardSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withOpacity(0.7)),
        ),
        child: Icon(icon, color: Colors.white70),
      ),
    );
  }
}

class _AdminDashboardStats {
  const _AdminDashboardStats({
    this.totalUsers = 0,
    this.totalContests = 0,
    this.openTickets = 0,
    this.revenue = 0,
    this.activeContests = 0,
    this.unpaidInvoices = 0,
    this.failedPayments = 0,
    this.totalEmployees = 0,
    this.totalParticipants = 0,
    this.totalSponsors = 0,
    this.activeUsers = 0,
    this.userTimeline = const [0, 0, 0, 0, 0, 0, 0],
    this.recentUsers = const [],
  });

  final int totalUsers;
  final int totalContests;
  final int openTickets;
  final double revenue;
  final int activeContests;
  final int unpaidInvoices;
  final int failedPayments;
  final int totalEmployees;
  final int totalParticipants;
  final int totalSponsors;
  final int activeUsers;
  final List<int> userTimeline;
  final List<_RecentUserRow> recentUsers;
}

class _RecentUserRow {
  const _RecentUserRow({
    required this.name,
    required this.role,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  final String name;
  final String role;
  final String email;
  final String status;
  final DateTime? createdAt;
}

class _PieSegment {
  const _PieSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments, required this.total});

  final List<_PieSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2 - 8;
    final stroke = radius * 0.28;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withOpacity(0.06)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);
    if (total <= 0) return;

    var start = -1.5708;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * 6.28318;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = segment.color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep + 0.06;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.segments != segments;
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.maxValue,
  });

  final List<int> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(6, 10, 6, 12);
    final chart = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * (i / 3);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    if (values.isEmpty) return;
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x =
          chart.left +
          chart.width * (i / (values.length - 1 == 0 ? 1 : values.length - 1));
      final normalized = values[i] / maxValue;
      final y = chart.bottom - (chart.height * normalized);
      points.add(Offset(x, y));
    }
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, chart.bottom)
      ..lineTo(points.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.2, Paint()..color = lineColor);
      canvas.drawCircle(point, 6, Paint()..color = lineColor.withOpacity(0.12));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxValue != maxValue;
  }
}

DateTime? _dateFromAny(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _initialsFromName(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _shortDate(DateTime? value) {
  if (value == null) return '--';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]}';
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
