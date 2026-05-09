import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';
import '../../services/contest_report_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/pdf_preview_screen.dart';
import '../../widgets/news_slider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/password_change_layout.dart';
import '../../widgets/settings_action_tile.dart';
import '../payments/sponsorship_payment_screen.dart';
import '../shared/contest_video_review_screen.dart';
import '../shared/legal_center_screen.dart';
import '../shared/support_chat_screen.dart';
import '../auth/login_screen.dart';

class SponsorHome extends StatefulWidget {
  const SponsorHome({super.key, required this.displayName});

  final String displayName;

  @override
  State<SponsorHome> createState() => _SponsorHomeState();
}

class _SponsorHomeState extends State<SponsorHome> {
  int _index = 0;

  String _title() {
    switch (_index) {
      case 0:
        return context.tr('Dashboard');
      case 1:
        return context.tr('My Contests');
      case 2:
        return context.tr('Applications');
      default:
        return context.tr('Profile');
    }
  }

  IconData _icon() {
    switch (_index) {
      case 0:
        return Icons.dashboard_rounded;
      case 1:
        return Icons.assignment;
      case 2:
        return Icons.campaign;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';

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
                              context.tr(_title()),
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
                      _SponsorDashboardTab(
                        uid: uid,
                        displayName: widget.displayName,
                        onOpenContests: () => setState(() => _index = 1),
                        onOpenApplications: () => setState(() => _index = 2),
                        onOpenCreate: () => _openCreateContest(uid),
                        onOpenSupport: () {
                          if (user == null) return;
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
                      _SponsorContestsTab(uid: uid),
                      _SponsorAdsTab(uid: uid),
                      _SponsorProfileTab(displayName: widget.displayName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: uid.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openCreateContest(uid),
              backgroundColor: AppColors.hotPink,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 34),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                  icon: Icon(Icons.analytics_outlined),
                  activeIcon: Icon(Icons.analytics),
                  label: context.tr('Dashboard'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: context.tr('My Contests'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.campaign_outlined),
                  activeIcon: Icon(Icons.campaign),
                  label: context.tr('Applications'),
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: context.tr('Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateContest(String uid) async {
    if (uid.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SponsorCreateCampaignScreen(uid: uid)),
    );
  }
}

class _SponsorContestsTab extends StatelessWidget {
  const _SponsorContestsTab({required this.uid});

  final String uid;
  static final ContestReportService _reportService = ContestReportService();

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return Center(child: Text(context.tr('Please login.')));
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .where('sponsorId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.tr(
                  'Unable to load contests right now.\nPlease try again.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final at =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            final bt =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            return bt.compareTo(at);
          });
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NewsSlider(),
              const SizedBox(height: 12),
              _EmptyHint(message: context.tr('No contests assigned yet.')),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const NewsSlider();
            }
            final doc = docs[index - 1];
            final data = doc.data();
            final title = (data['title'] ?? doc.id).toString();
            final details = (data['description'] ?? '').toString();
            final logoUrl = (data['logoUrl'] ?? '').toString();
            final challengeQuestion = (data['challengeQuestion'] ?? '')
                .toString();
            final winnerPrize = ((data['winnerPrize'] ?? 100) as num)
                .toDouble();

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.cardSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.campaign,
                                color: AppColors.hotPink,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (challengeQuestion.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('Challenge')}: $challengeQuestion',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.hotPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showContestView(
                          context: context,
                          contestId: doc.id,
                          data: data,
                        ),
                        icon: const Icon(Icons.visibility),
                        label: Text(context.tr('Contest Details')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openContestReport(
                          context: context,
                          contestId: doc.id,
                          data: data,
                        ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: Text(context.tr('Contest Report')),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showContestView({
    required BuildContext context,
    required String contestId,
    required Map<String, dynamic> data,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _SponsorContestDetailPage(contestId: contestId, data: data),
      ),
    );
  }

  Future<void> _openContestReport({
    required BuildContext context,
    required String contestId,
    required Map<String, dynamic> data,
  }) async {
    final title = (data['title'] ?? contestId).toString();
    final bytes = await _reportService.buildContestReportFromFirestore(
      contestId: contestId,
      contestData: data,
    );
    if (!context.mounted) return;
    final safe = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          title: context.tr('Contest Report'),
          bytes: bytes,
          filename: '$safe-contest-report.pdf',
        ),
      ),
    );
  }

  Future<void> _showCommentDialog({
    required BuildContext context,
    required String contestId,
    required String submissionId,
  }) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Add Sponsor Comment')),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.tr('Write your comment for admin review...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(context.tr('Submit')),
          ),
        ],
      ),
    );
    if (comment == null || comment.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final sponsorId = user?.uid ?? '';
    final sponsorName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email ?? 'Sponsor');

    final subRef = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .doc(submissionId);
    await subRef.collection('sponsor_comments').add({
      'sponsorId': sponsorId,
      'sponsorName': sponsorName,
      'comment': comment,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'submission',
      'entityId': submissionId,
      'contestId': contestId,
      'action': 'sponsor_comment',
      'actorId': sponsorId,
      'reason': comment,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Comment sent to admin.'))),
      );
    }
  }

  Future<void> _reportVideo({
    required BuildContext context,
    required String contestId,
    required String submissionId,
    required Map<String, dynamic> submissionData,
  }) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Report Video')),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Reason (required)'),
            hintText: context.tr('Why should this be reviewed?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(context.tr('Report')),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final sponsorName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email ?? 'Sponsor');
    final sponsorId = user?.uid ?? '';
    final contestAdminId = (submissionData['contestAdminId'] ?? '').toString();
    final submissionRef = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .doc(submissionId);

    await submissionRef.set({
      'status': 'under_review',
      'sponsorReportedBy': sponsorId,
      'sponsorReportedByName': sponsorName,
      'sponsorReportReason': reason,
      'sponsorReportedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'submission',
      'entityId': submissionId,
      'contestId': contestId,
      'action': 'sponsor_report',
      'actorId': sponsorId,
      'reason': reason,
      'beforeStatus': (submissionData['status'] ?? '').toString(),
      'afterStatus': 'under_review',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    if (contestAdminId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(contestAdminId)
          .collection('notifications')
          .add({
            'title': 'Video Reported By Sponsor',
            'message':
                '${context.tr('A sponsor reported a video.')} ${context.tr('Reason')}: $reason',
            'contestId': contestId,
            'submissionId': submissionId,
            'read': false,
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Video reported and sent for admin review.')),
      ),
    );
  }

  Future<void> _openVideoDialog({
    required BuildContext context,
    required String videoUrl,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SponsorVideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF2DAF6F);
      case 'under_review':
        return const Color(0xFF5AB4FF);
      case 'rejected':
        return const Color(0xFFC53D5D);
      case 'removed':
        return const Color(0xFF9B8AA8);
      default:
        return AppColors.sunset;
    }
  }
}

class _SponsorContestDetailPage extends StatefulWidget {
  const _SponsorContestDetailPage({
    required this.contestId,
    required this.data,
  });

  final String contestId;
  final Map<String, dynamic> data;

  @override
  State<_SponsorContestDetailPage> createState() =>
      _SponsorContestDetailPageState();
}

class _SponsorContestDetailPageState extends State<_SponsorContestDetailPage> {
  String _readDate(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    return '--';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF2DAF6F);
      case 'under_review':
        return const Color(0xFF5AB4FF);
      case 'rejected':
        return const Color(0xFFC53D5D);
      case 'removed':
        return const Color(0xFF9B8AA8);
      default:
        return AppColors.sunset;
    }
  }

  Future<void> _showCommentDialog({required String submissionId}) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Add Sponsor Comment')),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.tr('Write your comment for admin review...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(context.tr('Submit')),
          ),
        ],
      ),
    );
    if (comment == null || comment.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final sponsorId = user?.uid ?? '';
    final sponsorName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email ?? 'Sponsor');

    final subRef = FirebaseFirestore.instance
        .collection('contests')
        .doc(widget.contestId)
        .collection('submissions')
        .doc(submissionId);
    await subRef.collection('sponsor_comments').add({
      'sponsorId': sponsorId,
      'sponsorName': sponsorName,
      'comment': comment,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'submission',
      'entityId': submissionId,
      'contestId': widget.contestId,
      'action': 'sponsor_comment',
      'actorId': sponsorId,
      'reason': comment,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Comment sent to admin.'))),
    );
  }

  Future<void> _reportVideo({
    required String submissionId,
    required Map<String, dynamic> submissionData,
  }) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Report Video')),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Reason (required)'),
            hintText: context.tr('Why should this be reviewed?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(context.tr('Report')),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final sponsorName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email ?? 'Sponsor');
    final sponsorId = user?.uid ?? '';
    final contestAdminId = (submissionData['contestAdminId'] ?? '').toString();
    final submissionRef = FirebaseFirestore.instance
        .collection('contests')
        .doc(widget.contestId)
        .collection('submissions')
        .doc(submissionId);

    await submissionRef.set({
      'status': 'under_review',
      'sponsorReportedBy': sponsorId,
      'sponsorReportedByName': sponsorName,
      'sponsorReportReason': reason,
      'sponsorReportedAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'submission',
      'entityId': submissionId,
      'contestId': widget.contestId,
      'action': 'sponsor_report',
      'actorId': sponsorId,
      'reason': reason,
      'beforeStatus': (submissionData['status'] ?? '').toString(),
      'afterStatus': 'under_review',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    if (contestAdminId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(contestAdminId)
          .collection('notifications')
          .add({
            'title': 'Video Reported By Sponsor',
            'message':
                '${context.tr('A sponsor reported a video.')} ${context.tr('Reason')}: $reason',
            'contestId': widget.contestId,
            'submissionId': submissionId,
            'read': false,
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Video reported and sent for admin review.')),
      ),
    );
  }

  Future<void> _openVideoDialog(String videoUrl) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SponsorVideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contestDocStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(widget.contestId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Contest Details')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: contestDocStream,
            builder: (context, contestSnap) {
              if (contestSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr(
                        'Unable to load contest details. Please check permissions and try again.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!contestSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final contestData = contestSnap.data!.data() ?? widget.data;
              final title = (contestData['title'] ?? '').toString();
              final description = (contestData['description'] ?? '').toString();

              final submissionsStream = FirebaseFirestore.instance
                  .collection('contests')
                  .doc(widget.contestId)
                  .collection('submissions')
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: submissionsStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.tr(
                            'Unable to load participant videos for this contest.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final at =
                          (a.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      final bt =
                          (b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0;
                      return bt.compareTo(at);
                    });
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? context.tr('Contest') : title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${context.tr('Submission')}: ${_readDate(contestData['submissionStart'])} ${context.tr('to')} ${_readDate(contestData['submissionEnd'])}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${context.tr('Voting')}: ${_readDate(contestData['votingStart'])} ${context.tr('to')} ${_readDate(contestData['votingEnd'])}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ContestVideoReviewSection(
                        contestId: widget.contestId,
                        contestData: contestData,
                        isSponsor: true,
                      ),
                      const SizedBox(height: 12),
                      if (docs.isEmpty)
                        _EmptyHint(
                          message: context.tr('No participant videos yet.'),
                        )
                      else
                        ...docs.map((doc) {
                          final d = doc.data();
                          final status = (d['status'] ?? 'pending').toString();
                          final videoUrl = (d['videoUrl'] ?? '').toString();
                          final userName = (d['userName'] ?? d['userId'] ?? '')
                              .toString();
                          final votes = ((d['voteCount'] ?? 0) as num).toInt();
                          final rejectionReason = (d['rejectionReason'] ?? '')
                              .toString();
                          final removedReason = (d['removedReason'] ?? '')
                              .toString();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          userName.isEmpty
                                              ? context.tr('Participant')
                                              : userName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          status == 'active'
                                              ? context.tr('Active')
                                              : status == 'contest_created'
                                              ? context.tr('Contest Created')
                                              : status == 'needs_improvement'
                                              ? context.tr('Needs Improvement')
                                              : status == 'rejected'
                                              ? context.tr('Rejected')
                                              : status == 'approved'
                                              ? context.tr('Approved')
                                              : status == 'live'
                                              ? context.tr('Live')
                                              : status.replaceAll('_', ' '),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${context.tr('Votes')}: $votes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (rejectionReason.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.tr('Rejection')}: $rejectionReason',
                                      style: const TextStyle(
                                        color: AppColors.sunset,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  if (removedReason.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${context.tr('Removed')}: $removedReason',
                                      style: const TextStyle(
                                        color: AppColors.sunset,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: videoUrl.isEmpty
                                            ? null
                                            : () => _openVideoDialog(videoUrl),
                                        icon: const Icon(
                                          Icons.play_circle_outline,
                                        ),
                                        label: Text(context.tr('Watch')),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showCommentDialog(
                                          submissionId: doc.id,
                                        ),
                                        icon: const Icon(Icons.chat_bubble),
                                        label: Text(context.tr('Comment')),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: status == 'removed'
                                            ? null
                                            : () => _reportVideo(
                                                submissionId: doc.id,
                                                submissionData: d,
                                              ),
                                        icon: const Icon(Icons.flag_outlined),
                                        label: Text(context.tr('Report')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SponsorDashboardTab extends StatelessWidget {
  const _SponsorDashboardTab({
    required this.uid,
    required this.displayName,
    required this.onOpenContests,
    required this.onOpenApplications,
    required this.onOpenCreate,
    required this.onOpenSupport,
  });

  final String uid;
  final String displayName;
  final VoidCallback onOpenContests;
  final VoidCallback onOpenApplications;
  final VoidCallback onOpenCreate;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return Center(child: Text(context.tr('Please login.')));

    final contestsStream = FirebaseFirestore.instance
        .collection('contests')
        .where('sponsorId', isEqualTo: uid)
        .snapshots();
    final applicationsStream = FirebaseFirestore.instance
        .collection('sponsorship_applications')
        .where('sponsorId', isEqualTo: uid)
        .snapshots();
    final supportMessagesStream = FirebaseFirestore.instance
        .collection('support_threads')
        .doc(uid)
        .collection('messages')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: contestsStream,
      builder: (context, contestSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: applicationsStream,
          builder: (context, applicationSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: supportMessagesStream,
              builder: (context, supportSnapshot) {
                if (!contestSnapshot.hasData || !applicationSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contests = contestSnapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final at =
                        (a.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bt =
                        (b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bt.compareTo(at);
                  });
                final applications = applicationSnapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final at =
                        (a.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bt =
                        (b.data()['createdAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bt.compareTo(at);
                  });
                final supportMessages = supportSnapshot.data?.docs ?? const [];

                final activeContests = contests.where((doc) {
                  final status = (doc.data()['status'] ?? '').toString();
                  return status == 'active' ||
                      status == 'approved' ||
                      status == 'live';
                }).toList();
                final pendingContests = applications.where((doc) {
                  final status = (doc.data()['applicationStatus'] ?? 'pending')
                      .toString();
                  return status == 'pending' ||
                      status == 'needs_improvement' ||
                      status == 'unpaid';
                }).toList();
                final draftCount = applications.where((doc) {
                  final status = (doc.data()['applicationStatus'] ?? 'pending')
                      .toString();
                  final payment = (doc.data()['paymentStatus'] ?? 'unpaid')
                      .toString();
                  return payment != 'paid' || status == 'needs_improvement';
                }).length;
                final adminReplyCount = supportMessages.where((doc) {
                  final senderRole = (doc.data()['senderRole'] ?? '')
                      .toString();
                  return senderRole == 'admin';
                }).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    _SponsorWelcomeCard(
                      displayName: displayName,
                      hasContests:
                          contests.isNotEmpty || applications.isNotEmpty,
                      onCreate: onOpenCreate,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.tr('Quick Actions'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.55,
                      children: [
                        _SponsorQuickActionCard(
                          icon: Icons.emoji_events_rounded,
                          color: const Color(0xFF7C83FF),
                          title: context.tr('My Contests'),
                          value: contests.length.toString(),
                          onTap: onOpenContests,
                        ),
                        _SponsorQuickActionCard(
                          icon: Icons.assignment_rounded,
                          color: const Color(0xFFFFB14A),
                          title: context.tr('Drafts'),
                          value: draftCount.toString(),
                          onTap: onOpenApplications,
                        ),
                        _SponsorQuickActionCard(
                          icon: Icons.auto_graph_rounded,
                          color: const Color(0xFF33D18A),
                          title: context.tr('Active'),
                          value: activeContests.length.toString(),
                          onTap: onOpenContests,
                        ),
                        _SponsorQuickActionCard(
                          icon: Icons.inbox_rounded,
                          color: const Color(0xFF8A8CFF),
                          title: context.tr('Inbox'),
                          value: adminReplyCount.toString(),
                          onTap: onOpenSupport,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (pendingContests.isNotEmpty) ...[
                      _SponsorSectionHeader(
                        title: context.tr('Pending Contests'),
                        actionLabel: context.tr('View All'),
                        onTap: onOpenApplications,
                      ),
                      const SizedBox(height: 10),
                      ...pendingContests
                          .take(3)
                          .map(
                            (doc) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SponsorPendingContestCard(
                                data: doc.data(),
                              ),
                            ),
                          ),
                      const SizedBox(height: 10),
                    ],
                    if (activeContests.isNotEmpty) ...[
                      _SponsorSectionHeader(
                        title: context.tr('Active Contests'),
                        actionLabel: context.tr('View All'),
                        onTap: onOpenContests,
                      ),
                      const SizedBox(height: 10),
                      ...activeContests
                          .take(3)
                          .map(
                            (doc) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SponsorLiveContestCard(data: doc.data()),
                            ),
                          ),
                      const SizedBox(height: 10),
                    ],
                    if (activeContests.isEmpty && pendingContests.isEmpty)
                      _EmptyHint(
                        message: context.tr(
                          'Create your first contest and start receiving amazing videos!',
                        ),
                      ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Need Help?'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'Our team is here to help you create a successful contest.',
                            ),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: onOpenSupport,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4C3B88),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(context.tr('Contact Support')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SponsorStatCard extends StatelessWidget {
  const _SponsorStatCard({
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
      padding: const EdgeInsets.all(14),
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
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SponsorWelcomeCard extends StatelessWidget {
  const _SponsorWelcomeCard({
    required this.displayName,
    required this.hasContests,
    required this.onCreate,
  });

  final String displayName;
  final bool hasContests;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final initials = displayName.trim().isEmpty
        ? 'SB'
        : displayName
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
              .join();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A121C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF273545)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFB144FF), Color(0xFF6F39FF)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Welcome,'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('Business Account'),
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  hasContests
                      ? Icons.rocket_launch_rounded
                      : Icons.emoji_events_rounded,
                  size: 50,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 14),
                Text(
                  hasContests
                      ? context.tr('Ready to launch your next contest?')
                      : context.tr("You don't have any contests yet"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  hasContests
                      ? context.tr(
                          'Create another contest and keep your audience engaged.',
                        )
                      : context.tr(
                          'Create your first contest and start receiving amazing videos!',
                        ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.hotPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      hasContests
                          ? context.tr('Create Contest')
                          : context.tr('Create Your First Contest'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _SponsorQuickActionCard extends StatelessWidget {
  const _SponsorQuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorSectionHeader extends StatelessWidget {
  const _SponsorSectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _SponsorPendingContestCard extends StatelessWidget {
  const _SponsorPendingContestCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title =
        (data['applicationName'] ??
                data['companySponsorName'] ??
                context.tr('Contest'))
            .toString();
    final region = (data['targetCountry'] ?? '').toString();
    final status = (data['applicationStatus'] ?? 'pending').toString();
    final payment = (data['paymentStatus'] ?? 'unpaid').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.hotPink.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
              color: AppColors.hotPink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  region.isEmpty
                      ? context.tr('Waiting for admin review')
                      : region,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusPill(
                label: status == 'needs_improvement'
                    ? context.tr('Needs Improvement')
                    : status == 'pending'
                    ? context.tr('Pending')
                    : status.replaceAll('_', ' '),
                color: status == 'needs_improvement'
                    ? AppColors.sunset
                    : AppColors.hotPink,
              ),
              const SizedBox(height: 6),
              Text(
                payment == 'paid' ? context.tr('Paid') : context.tr('Unpaid'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SponsorLiveContestCard extends StatelessWidget {
  const _SponsorLiveContestCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? context.tr('Contest')).toString();
    final description = (data['description'] ?? '').toString();
    final status = (data['status'] ?? 'active').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: AppColors.neonGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description.isEmpty
                      ? context.tr('Contest is live on Click Kick.')
                      : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statusPill(
            label: status == 'live'
                ? context.tr('Live')
                : status == 'approved'
                ? context.tr('Approved')
                : context.tr('Active'),
            color: AppColors.neonGreen,
          ),
        ],
      ),
    );
  }
}

Widget _statusPill({required String label, required Color color}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorAdsTab extends StatefulWidget {
  const _SponsorAdsTab({required this.uid});

  final String uid;

  @override
  State<_SponsorAdsTab> createState() => _SponsorAdsTabState();
}

class _SponsorAdsTabState extends State<_SponsorAdsTab> {
  Future<void> _openCreateCampaign({
    String? applicationId,
    Map<String, dynamic>? initialData,
  }) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SponsorCreateCampaignScreen(
          uid: widget.uid,
          applicationId: applicationId,
          initialData: initialData,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'live':
        return const Color(0xFF2EDB85);
      case 'contest_created':
        return const Color(0xFF5AB4FF);
      case 'approved':
        return AppColors.neonGreen;
      case 'needs_improvement':
        return AppColors.sunset;
      case 'rejected':
        return const Color(0xFFD64B6A);
      default:
        return AppColors.hotPink;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return Center(child: Text(context.tr('Please login.')));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sponsorship_applications')
          .where('sponsorId', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final at =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            final bt =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
            return bt.compareTo(at);
          });

        final total = docs.length;
        final approved = docs
            .where(
              (d) =>
                  (d.data()['applicationStatus'] ?? '').toString() ==
                  'approved',
            )
            .length;
        final rejected = docs
            .where(
              (d) =>
                  (d.data()['applicationStatus'] ?? '').toString() ==
                  'rejected',
            )
            .length;
        final needsRevision = docs
            .where(
              (d) =>
                  (d.data()['applicationStatus'] ?? '').toString() ==
                  'needs_improvement',
            )
            .length;
        final paid = docs
            .where(
              (d) => (d.data()['paymentStatus'] ?? '').toString() == 'paid',
            )
            .length;
        final active = docs.where((d) {
          final data = d.data();
          return (data['applicationStatus'] ?? '').toString() == 'approved' &&
              (data['paymentStatus'] ?? '').toString() == 'paid';
        }).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 980
                    ? 4
                    : width >= 760
                    ? 3
                    : width >= 390
                    ? 3
                    : 2;
                final ratio = width >= 980
                    ? 2.1
                    : width >= 760
                    ? 1.7
                    : crossAxisCount == 3
                    ? 1.12
                    : 1.35;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: ratio,
                  children: [
                    _MetricCard(
                      label: context.tr('Total'),
                      value: total.toString(),
                      color: AppColors.hotPink,
                      icon: Icons.campaign,
                    ),
                    _MetricCard(
                      label: context.tr('Active'),
                      value: active.toString(),
                      color: AppColors.neonGreen,
                      icon: Icons.bolt,
                    ),
                    _MetricCard(
                      label: context.tr('Paid'),
                      value: paid.toString(),
                      color: const Color(0xFF32C37A),
                      icon: Icons.payments,
                    ),
                    _MetricCard(
                      label: context.tr('Needs Edit'),
                      value: needsRevision.toString(),
                      color: AppColors.sunset,
                      icon: Icons.edit_note,
                    ),
                    _MetricCard(
                      label: context.tr('Rejected'),
                      value: rejected.toString(),
                      color: const Color(0xFFD64B6A),
                      icon: Icons.cancel,
                    ),
                    _MetricCard(
                      label: context.tr('Approved'),
                      value: approved.toString(),
                      color: const Color(0xFF54E37E),
                      icon: Icons.check_circle,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              const _EmptyHint(message: 'No sponsorship applications yet.')
            else
              ...docs.map((doc) {
                final d = doc.data();
                final title =
                    (d['companySponsorName'] ??
                            d['applicationName'] ??
                            'Application')
                        .toString();
                final country = (d['targetCountry'] ?? '').toString();
                final pay = (d['paymentStatus'] ?? 'unpaid').toString();
                final payLabel = pay == 'paid'
                    ? context.tr('Paid')
                    : pay == 'unpaid'
                    ? context.tr('Unpaid')
                    : pay;
                final review = (d['applicationStatus'] ?? 'pending').toString();
                final platformFee = ((d['applicationFee'] ?? 1000) as num)
                    .toDouble();
                final winnerPrize = ((d['winnerPrize'] ?? 100) as num)
                    .toDouble();
                final invoiceNumber = (d['invoiceNumber'] ?? '').toString();
                final reviewNote = (d['adminReviewNote'] ?? '').toString();
                final logoUrl = (d['logoUrl'] ?? '').toString();
                final brand = (d['brandName'] ?? '').toString();
                final product = (d['productName'] ?? '').toString();
                final extraPrizes = (d['additionalPrizes'] ?? '').toString();
                final questionOptions =
                    ((d['questionOptions'] as List?) ?? const [])
                        .map((e) => e.toString())
                        .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
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
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.cardSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: logoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront,
                                      color: AppColors.hotPink,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${context.tr('Region')}: $country',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(review).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                review == 'pending'
                                    ? context.tr('Pending')
                                    : review == 'approved'
                                    ? context.tr('Approved')
                                    : review == 'rejected'
                                    ? context.tr('Rejected')
                                    : review == 'needs_improvement'
                                    ? context.tr('Needs Improvement')
                                    : review == 'contest_created'
                                    ? context.tr('Contest Created')
                                    : review == 'live'
                                    ? context.tr('Live')
                                    : review.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: _statusColor(review),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.tr('Platform Fee')}: \$${platformFee.toStringAsFixed(0)} | ${context.tr('Payment')}: $payLabel',
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                        ),
                        if (brand.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Brand')}: $brand'),
                        ],
                        if (product.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Product')}: $product'),
                        ],
                        if (extraPrizes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Additional prizes')}: $extraPrizes',
                          ),
                        ],
                        if (invoiceNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('${context.tr('Invoice')}: $invoiceNumber'),
                        ],
                        if (questionOptions.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${context.tr('Questions')}: ${questionOptions.length} ${context.tr('submitted')}',
                          ),
                        ],
                        if (reviewNote.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${context.tr('Admin note')}: $reviewNote',
                            style: const TextStyle(color: AppColors.sunset),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (pay != 'paid')
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.payments, size: 16),
                                  label: Text(context.tr('Pay Now')),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.hotPink,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    try {
                                      final result = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SponsorshipPaymentScreen(
                                                applicationId: doc.id,
                                                amount: platformFee,
                                                title: title,
                                              ),
                                        ),
                                      );
                                      if (!mounted) return;
                                      if (result == true) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr(
                                                'Payment completed successfully.',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr(
                                              'Payment failed. Please try again.',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            if (review == 'needs_improvement' ||
                                review == 'rejected') ...[
                              if (pay != 'paid') const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openCreateCampaign(
                                    applicationId: doc.id,
                                    initialData: d,
                                  ),
                                  icon: const Icon(Icons.edit),
                                  label: Text(context.tr('Resubmit')),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _SponsorCreateCampaignScreen extends StatefulWidget {
  const _SponsorCreateCampaignScreen({
    required this.uid,
    this.applicationId,
    this.initialData,
  });

  final String uid;
  final String? applicationId;
  final Map<String, dynamic>? initialData;

  @override
  State<_SponsorCreateCampaignScreen> createState() =>
      _SponsorCreateCampaignScreenState();
}

class _SponsorCreateCampaignScreenState
    extends State<_SponsorCreateCampaignScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController();
  final _brand = TextEditingController();
  final _product = TextEditingController();
  final _additionalPrizes = TextEditingController();

  Uint8List? _logoBytes;
  List<Uint8List> _productImages = const [];
  List<String> _existingProductUrls = const [];
  String _existingLogoUrl = '';
  DateTime? _submissionStart;
  DateTime? _submissionEnd;
  DateTime? _votingStart;
  DateTime? _votingEnd;
  bool _saving = false;
  double _applicationFee = 1000;
  double _winnerPrize = 100;
  int _step = 0;
  String _videoSource = 'we_produce';
  String _category = 'Fashion';

  static const List<String> _categories = <String>[
    'Fashion',
    'Beauty',
    'Food',
    'Travel',
    'Technology',
    'Lifestyle',
  ];

  bool get _isEdit => widget.applicationId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    if (d != null) {
      _title.text = (d['applicationName'] ?? '').toString();
      _description.text = (d['description'] ?? '').toString();
      _country.text = (d['targetCountry'] ?? '').toString();
      _brand.text = (d['brandName'] ?? '').toString();
      _product.text = (d['productName'] ?? '').toString();
      _additionalPrizes.text = (d['additionalPrizes'] ?? '').toString();
      _existingLogoUrl = (d['logoUrl'] ?? '').toString();
      _existingProductUrls = ((d['productImageUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _submissionStart = _readDate(
        d['proposedSubmissionStart'] ?? d['submissionStart'],
      );
      _submissionEnd = _readDate(
        d['proposedSubmissionEnd'] ?? d['submissionEnd'],
      );
      _votingStart = _readDate(d['proposedVotingStart'] ?? d['votingStart']);
      _votingEnd = _readDate(d['proposedVotingEnd'] ?? d['votingEnd']);
      _applicationFee = ((d['applicationFee'] ?? 1000) as num).toDouble();
      _winnerPrize = ((d['winnerPrize'] ?? 100) as num).toDouble();
      _videoSource = (d['videoSource'] ?? 'we_produce').toString();
      _category = (d['category'] ?? 'Fashion').toString();
    }
    _loadSponsorshipFee();
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _pickDate(
    ValueSetter<DateTime?> setter,
    DateTime? initial,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => setter(picked));
    }
  }

  String _fmtDate(BuildContext context, DateTime? date) {
    if (date == null) return context.tr('Not set');
    final d = date.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _loadSponsorshipFee() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('sponsorship')
        .get();
    final data = doc.data() ?? {};
    final fee = ((data['applicationFee'] ?? 1000) as num).toDouble();
    final winner = ((data['winnerPrize'] ?? 100) as num).toDouble();
    if (!mounted) return;
    setState(() {
      _applicationFee = fee;
      _winnerPrize = winner;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _country.dispose();
    _brand.dispose();
    _product.dispose();
    _additionalPrizes.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _logoBytes = bytes);
  }

  Future<void> _pickProducts() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    final out = <Uint8List>[];
    for (final f in files) {
      out.add(await f.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _productImages = out);
  }

  Future<void> _pickCountry() async {
    Country? selected;
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.card,
        textStyle: TextStyle(color: AppColors.textLight),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        bottomSheetHeight: 560,
        inputDecoration: InputDecoration(
          labelText: context.tr('Search country'),
          prefixIcon: Icon(Icons.search),
        ),
      ),
      onSelect: (country) {
        selected = country;
        if (!mounted) return;
        setState(() => _country.text = selected!.name);
      },
    );
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep(finalStep: true)) return;

    setState(() => _saving = true);
    final now = Timestamp.fromDate(DateTime.now());
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final authUser = FirebaseAuth.instance.currentUser;
    final sponsorName =
        (userData['displayName'] ??
                userData['companyName'] ??
                authUser?.displayName ??
                'Sponsor')
            .toString();
    final sponsorEmail = (userData['email'] ?? authUser?.email ?? '')
        .toString();
    final sponsorCompany = (userData['companyName'] ?? '').toString();
    final docRef = widget.applicationId == null
        ? FirebaseFirestore.instance
              .collection('sponsorship_applications')
              .doc()
        : FirebaseFirestore.instance
              .collection('sponsorship_applications')
              .doc(widget.applicationId);

    String logoUrl = _existingLogoUrl;
    if (_logoBytes != null) {
      final logoRef = FirebaseStorage.instance.ref().child(
        'sponsorship_applications/${docRef.id}/logo_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await logoRef.putData(_logoBytes!);
      logoUrl = await logoRef.getDownloadURL();
    }

    final productUrls = <String>[..._existingProductUrls];
    if (_productImages.isNotEmpty) {
      for (var i = 0; i < _productImages.length; i++) {
        final ref = FirebaseStorage.instance.ref().child(
          'sponsorship_applications/${docRef.id}/products/${DateTime.now().millisecondsSinceEpoch}_$i.png',
        );
        await ref.putData(_productImages[i]);
        productUrls.add(await ref.getDownloadURL());
      }
    }

    final questions = <String>[
      'What do you like most about ${_title.text.trim()}?',
      'How would you style or use this product creatively?',
      'Why should your video win this contest?',
    ];
    final baseData = {
      'sponsorId': widget.uid,
      'sponsorName': sponsorName,
      'sponsorEmail': sponsorEmail,
      'companyName': sponsorCompany,
      'applicationName': _title.text.trim(),
      'companySponsorName': _title.text.trim(),
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'category': _category,
      'targetCountry': _country.text.trim(),
      'brandName': _brand.text.trim().isEmpty ? _category : _brand.text.trim(),
      'productName': _product.text.trim(),
      'additionalPrizes': _additionalPrizes.text.trim(),
      'questionOptions': questions,
      'selectedQuestion': '',
      'selectedQuestionIndex': null,
      'logoUrl': logoUrl,
      'productImageUrls': productUrls,
      'videoSource': _videoSource,
      'applicationFee': _applicationFee,
      'winnerPrize': _winnerPrize,
      'applicationStatus': 'pending',
      'adminReviewNote': '',
      'proposedSubmissionStart': Timestamp.fromDate(_submissionStart!),
      'proposedSubmissionEnd': Timestamp.fromDate(_submissionEnd!),
      'proposedVotingStart': Timestamp.fromDate(_votingStart!),
      'proposedVotingEnd': Timestamp.fromDate(_votingEnd!),
      'updatedAt': now,
    };

    if (_isEdit) {
      await docRef.set(baseData, SetOptions(merge: true));
    } else {
      await docRef.set({
        ...baseData,
        'paymentStatus': 'unpaid',
        'invoiceNumber': '',
        'invoiceUrl': '',
        'createdAt': now,
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  bool _validateCurrentStep({bool finalStep = false}) {
    if (_title.text.trim().isEmpty) {
      _showContestMessage(context.tr('Contest name is required.'));
      return false;
    }
    if (_country.text.trim().isEmpty) {
      _showContestMessage(context.tr('Target country is required.'));
      return false;
    }
    if (_submissionStart == null ||
        _submissionEnd == null ||
        _votingStart == null ||
        _votingEnd == null) {
      _showContestMessage(
        context.tr('Please set submission and voting dates.'),
      );
      return false;
    }
    if (_step == 1 && _videoSource.isEmpty) {
      _showContestMessage(context.tr('Please choose a video source option.'));
      return false;
    }
    return true;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    setState(() => _step += 1);
  }

  void _backStep() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  void _showContestMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Create Contest')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_step + 1} of 4',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _SponsorContestStepper(step: _step),
                const SizedBox(height: 26),
                if (_step == 0) _buildBasicInformationStep(context),
                if (_step == 1) _buildVideoSourceStep(context),
                if (_step == 2) _buildPricingStep(context),
                if (_step == 3) _buildPreviewStep(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInformationStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Basic Information'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _title,
          decoration: InputDecoration(labelText: context.tr('Contest Name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Contest Description'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _categories.contains(_category)
              ? _category
              : _categories.first,
          dropdownColor: AppColors.card,
          decoration: InputDecoration(labelText: context.tr('Category')),
          items: _categories
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(context.tr(category)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _country,
          readOnly: true,
          onTap: _pickCountry,
          decoration: InputDecoration(
            labelText: context.tr('Target Country/Region'),
            suffixIcon: IconButton(
              onPressed: _pickCountry,
              icon: const Icon(Icons.arrow_drop_down),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: context.tr('Start Date'),
                value: _fmtDate(context, _submissionStart),
                onTap: () =>
                    _pickDate((v) => _submissionStart = v, _submissionStart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateTile(
                label: context.tr('End Date'),
                value: _fmtDate(context, _submissionEnd),
                onTap: () =>
                    _pickDate((v) => _submissionEnd = v, _submissionEnd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: context.tr('Voting Start'),
                value: _fmtDate(context, _votingStart),
                onTap: () => _pickDate((v) => _votingStart = v, _votingStart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateTile(
                label: context.tr('Voting End'),
                value: _fmtDate(context, _votingEnd),
                onTap: () => _pickDate((v) => _votingEnd = v, _votingEnd),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        GradientButton(label: context.tr('Next Step'), onPressed: _nextStep),
      ],
    );
  }

  Widget _buildVideoSourceStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Video Source'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(
            'Choose how you want to provide the video for this contest.',
          ),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _videoSourceCard(
          selected: _videoSource == 'we_produce',
          title: context.tr('We produce the video'),
          subtitle: context.tr(
            'Our team will produce a professional video for your contest.',
          ),
          amount: '\$250',
          onTap: () => setState(() => _videoSource = 'we_produce'),
        ),
        const SizedBox(height: 14),
        _videoSourceCard(
          selected: _videoSource == 'you_provide',
          title: context.tr('You provide the video'),
          subtitle: context.tr(
            'You already have a video and will upload it for the contest.',
          ),
          amount: '\$0',
          onTap: () => setState(() => _videoSource = 'you_provide'),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _logoBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                  )
                : _existingLogoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(_existingLogoUrl, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      context.tr('Upload brand logo'),
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickProducts,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(context.tr('Upload Product Images')),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._existingProductUrls.map(
              (u) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  u,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ..._productImages.map(
              (b) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  b,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _backStep,
                child: Text(context.tr('Back')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: context.tr('Next Step'),
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingStep(BuildContext context) {
    final videoFee = _videoSource == 'we_produce' ? 250.0 : 0.0;
    final total = videoFee + _applicationFee + _winnerPrize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Plan & Pricing Summary'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('Review the details of your contest plan.'),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _summaryRow(
                context.tr('Video Production (by us)'),
                '\$${videoFee.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 10),
              _summaryRow(
                context.tr('Contest Management Fee'),
                '\$${_applicationFee.toStringAsFixed(0)}',
              ),
              const SizedBox(height: 10),
              _summaryRow(
                context.tr('Winner Prize (included)'),
                '\$${_winnerPrize.toStringAsFixed(0)}',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppColors.border),
              ),
              _summaryRow(
                context.tr('Total Amount'),
                '\$${total.toStringAsFixed(0)} USD',
                highlight: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.tr("What's Included?"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ...<String>[
          'Professional video production',
          'Contest setup & management',
          'Promotion on Click Kick platform',
          'Voting system',
          'Support & analytics',
          '\$${_winnerPrize.toStringAsFixed(0)} prize for the winner',
        ].map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.neonGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr(line),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _backStep,
                child: Text(context.tr('Back')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                label: context.tr('Next Step'),
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewStep(BuildContext context) {
    final videoFee = _videoSource == 'we_produce' ? 250.0 : 0.0;
    final total = videoFee + _applicationFee + _winnerPrize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Contest Preview'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('Review everything before publishing.'),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_logoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _logoBytes!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (_existingLogoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _existingLogoUrl,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.cardSoft,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _title.text.trim().isEmpty
                        ? context.tr('Contest Preview')
                        : _title.text.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _previewRow(context.tr('Contest Name'), _title.text.trim()),
              _previewRow(context.tr('Category'), _category),
              _previewRow(
                context.tr('Period'),
                '${_fmtDate(context, _submissionStart)} - ${_fmtDate(context, _submissionEnd)}',
              ),
              _previewRow(
                context.tr('Video Source'),
                _videoSource == 'we_produce'
                    ? context.tr('We produce the video')
                    : context.tr('You provide the video'),
              ),
              _previewRow(
                context.tr('Total Amount'),
                '\$${total.toStringAsFixed(0)} USD',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: _saving
              ? context.tr('Saving...')
              : (_isEdit
                    ? context.tr('Publish Contest')
                    : context.tr('Publish Contest')),
          onPressed: _saving ? () {} : _submit,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _backStep,
            child: Text(context.tr('Back')),
          ),
        ),
      ],
    );
  }

  Widget _videoSourceCard({
    required bool selected,
    required String title,
    required String subtitle,
    required String amount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.hotPink : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.hotPink : AppColors.textMuted,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.hotPink.withOpacity(0.14)
                    : AppColors.cardSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Production Fee'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : AppColors.textLight,
              fontSize: highlight ? 19 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? AppColors.gold : Colors.white,
            fontSize: highlight ? 20 : 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsorContestStepper extends StatelessWidget {
  const _SponsorContestStepper({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final active = index <= step;
        final current = index == step;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? (current ? AppColors.hotPink : const Color(0xFF7A4DFF))
                      : const Color(0xFF2A3340),
                ),
                alignment: Alignment.center,
                child: current
                    ? Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Icon(
                        active ? Icons.auto_awesome_rounded : Icons.circle,
                        size: active ? 16 : 10,
                        color: Colors.white,
                      ),
              ),
              if (index < 3)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: index < step
                          ? const Color(0xFF7A4DFF)
                          : const Color(0xFF2A3340),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorProfileTab extends StatelessWidget {
  const _SponsorProfileTab({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(child: Text(context.tr('Please login.')));
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['displayName'] ?? user.displayName ?? displayName)
            .toString();
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
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                    builder: (_) => _SponsorProfileInfoScreen(user: user),
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
                    builder: (_) => _SponsorProfileUpdateScreen(
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
                    builder: (_) => const _SponsorSecurityScreen(),
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
                  MaterialPageRoute(builder: (_) => const LegalCenterScreen()),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.delete_outline_rounded,
              title: context.tr('Delete Account'),
              subtitle: context.tr('Permanently remove your account.'),
              isDanger: true,
              onTap: () async {
                final confirmed = await showDeleteAccountDialog(context);
                if (confirmed != true) return;
                try {
                  await AuthService().deleteCurrentAccount();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('Account deleted successfully.'),
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
                      ? context.tr(
                          'Please login again before deleting your account.',
                        )
                      : context.tr(
                          'Unable to delete account right now. Please try again.',
                        );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
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

class _SponsorProfileInfoScreen extends StatelessWidget {
  const _SponsorProfileInfoScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profile Info'))),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final rows = <MapEntry<String, String>>[
            MapEntry(
              context.tr('Full Name'),
              (data['displayName'] ?? user.displayName ?? '').toString(),
            ),
            MapEntry(
              context.tr('Email'),
              (data['email'] ?? user.email ?? '').toString(),
            ),
            MapEntry(
              context.tr('Phone number'),
              '${(data['phoneCountryCode'] ?? '').toString()} ${(data['phoneNumber'] ?? '').toString()}'
                  .trim(),
            ),
            MapEntry(context.tr('Country'), (data['country'] ?? '').toString()),
            MapEntry(
              context.tr('Company Name'),
              (data['companyName'] ?? '').toString(),
            ),
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
                  children: rows
                      .map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.key,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row.value.isEmpty ? '-' : row.value,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
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
        },
      ),
    );
  }
}

class _SponsorProfileUpdateScreen extends StatefulWidget {
  const _SponsorProfileUpdateScreen({
    required this.user,
    required this.displayName,
  });

  final User user;
  final String displayName;

  @override
  State<_SponsorProfileUpdateScreen> createState() =>
      _SponsorProfileUpdateScreenState();
}

class _SponsorProfileUpdateScreenState
    extends State<_SponsorProfileUpdateScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _country = TextEditingController();
  final _company = TextEditingController();
  final _phoneCode = TextEditingController(text: '+1');
  final _phoneNumber = TextEditingController();
  String _phoneIso = 'US';
  final _currentPassword = TextEditingController();
  bool _saving = false;
  bool _loading = true;
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
    final data = doc.data() ?? {};
    _name.text =
        (data['displayName'] ?? widget.user.displayName ?? widget.displayName)
            .toString();
    _email.text = (data['email'] ?? widget.user.email ?? '').toString();
    _country.text = (data['country'] ?? '').toString();
    _company.text = (data['companyName'] ?? '').toString();
    _phoneCode.text = (data['phoneCountryCode'] ?? '+1').toString();
    _phoneNumber.text = (data['phoneNumber'] ?? '').toString();
    _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _country.dispose();
    _company.dispose();
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
      await user.updateDisplayName(_name.text.trim());
      final newEmail = _email.text.trim();
      if (newEmail.isNotEmpty && newEmail != (user.email ?? '')) {
        final currentEmail = (user.email ?? '').trim();
        if (currentEmail.isEmpty) {
          _showSponsorMessage(
            context,
            'Current account email is missing. Please login again.',
          );
          setState(() => _saving = false);
          return;
        }
        if (_currentPassword.text.trim().isEmpty) {
          _showSponsorMessage(
            context,
            context.tr('Current password is required to change email.'),
          );
          setState(() => _saving = false);
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: currentEmail,
          password: _currentPassword.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.verifyBeforeUpdateEmail(newEmail);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _name.text.trim(),
        'email': user.email ?? '',
        'country': _country.text.trim(),
        'companyName': _company.text.trim(),
        'phoneCountryCode': _phoneCode.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumber.text.trim(),
        'phoneE164': '${_phoneCode.text.trim()}${_phoneNumber.text.trim()}',
        if (newEmail != (user.email ?? '')) 'pendingEmail': newEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      _showSponsorMessage(context, context.tr('Profile updated.'));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showSponsorMessage(
          context,
          context.tr('Current password is incorrect.'),
        );
      } else {
        _showSponsorMessage(
          context,
          context.tr('Profile update failed (${e.code}).'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.tr('Full Name'),
                  ),
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
                            labelText: context.tr('Country code'),
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
                  controller: _country,
                  decoration: InputDecoration(labelText: context.tr('Country')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _company,
                  decoration: InputDecoration(
                    labelText: context.tr('Company Name'),
                  ),
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
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
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

void _showSponsorMessage(BuildContext context, String message) {
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

class _SponsorSecurityScreen extends StatefulWidget {
  const _SponsorSecurityScreen();

  @override
  State<_SponsorSecurityScreen> createState() => _SponsorSecurityTabState();
}

class _SponsorSecurityTabState extends State<_SponsorSecurityScreen> {
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
    final email = (user?.email ?? '').trim();
    if (user == null || email.isEmpty) {
      _show(context.tr('Account email not found. Please login again.'));
      return;
    }
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
        email: email,
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
      } else if (e.code == 'requires-recent-login') {
        _show(context.tr('Please login again and try password update.'));
      } else {
        _show('Password update failed (${e.code}).');
      }
    } catch (_) {
      _show(context.tr('Password update failed. Please try again.'));
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
      onToggleCurrent: () => setState(() => _obscureCurrent = !_obscureCurrent),
      onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
      onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
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

class _SponsorVideoPlayerDialog extends StatefulWidget {
  const _SponsorVideoPlayerDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_SponsorVideoPlayerDialog> createState() =>
      _SponsorVideoPlayerDialogState();
}

class _SponsorVideoPlayerDialogState extends State<_SponsorVideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('Video Preview'),
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textLight),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  );
                }
                if (!_controller.value.isInitialized) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(context.tr('Unable to load video.')),
                  );
                }
                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () async {
                            final position = _controller.value.position;
                            await _controller.seekTo(
                              position - const Duration(seconds: 5),
                            );
                          },
                          icon: const Icon(
                            Icons.replay_5,
                            color: AppColors.textLight,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: AppColors.hotPink,
                            size: 34,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final position = _controller.value.position;
                            await _controller.seekTo(
                              position + const Duration(seconds: 5),
                            );
                          },
                          icon: const Icon(
                            Icons.forward_5,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
    );
  }
}
