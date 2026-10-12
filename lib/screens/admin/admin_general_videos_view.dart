import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/general_video_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/block_participant_dialog.dart';
import '../../widgets/moderation_stat_card.dart';
import '../profile/general_video_player_screen.dart';

/// Moderation list for General Videos, shown inside the admin "Video
/// Moderation" screen when the Video Type is "General". It uses the same
/// Approve / Reject flow as competition videos. General videos have no
/// competition, so no competition name is shown, and they stay `pending` until
/// an admin approves them.
class AdminGeneralVideosView extends StatelessWidget {
  const AdminGeneralVideosView({
    super.key,
    required this.search,
    required this.statusFilter,
  });

  final String search;
  final String statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('general_videos')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(context.tr('Unable to load videos.')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data!.docs;
        final totalCount = allDocs.length;
        final pendingCount = allDocs
            .where((d) => (d.data()['status'] ?? 'pending') == 'pending')
            .length;
        final approvedCount = allDocs
            .where((d) => (d.data()['status'] ?? 'pending') == 'approved')
            .length;
        final rejectedCount = allDocs
            .where((d) => (d.data()['status'] ?? 'pending') == 'rejected')
            .length;

        final docs =
            allDocs.where((doc) {
              final data = doc.data();
              final status = (data['status'] ?? 'pending').toString();
              if (statusFilter != 'all' && status != statusFilter) {
                return false;
              }
              if (search.isEmpty) return true;
              final haystack =
                  '${data['userName'] ?? ''} ${data['caption'] ?? ''}'
                      .toLowerCase();
              return haystack.contains(search);
            }).toList()..sort((a, b) {
              // Pending first (they need action), then newest.
              final ap = (a.data()['status'] ?? 'pending') == 'pending';
              final bp = (b.data()['status'] ?? 'pending') == 'pending';
              if (ap != bp) return ap ? -1 : 1;
              final at = (a.data()['createdAt'] as Timestamp?)?.toDate();
              final bt = (b.data()['createdAt'] as Timestamp?)?.toDate();
              return (bt ?? DateTime(2000)).compareTo(at ?? DateTime(2000));
            });

        // One scroll view for the stat cards and the list together, so the
        // cards aren't pinned eating into the (small) scrollable area —
        // they now scroll away with the rest of the content.
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 880
                        ? 4
                        : width > 620
                        ? 3
                        : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: width > 620 ? 1.55 : 1.8,
                      children: [
                        ModerationStatCard(
                          label: context.tr('Total Videos'),
                          value: '$totalCount',
                          icon: Icons.video_library_rounded,
                          color: const Color(0xFF5AB4FF),
                        ),
                        ModerationStatCard(
                          label: context.tr('Pending'),
                          value: '$pendingCount',
                          icon: Icons.hourglass_top_rounded,
                          color: AppColors.sunset,
                        ),
                        ModerationStatCard(
                          label: context.tr('Approved'),
                          value: '$approvedCount',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF2DAF6F),
                        ),
                        ModerationStatCard(
                          label: context.tr('Rejected'),
                          value: '$rejectedCount',
                          icon: Icons.cancel_rounded,
                          color: const Color(0xFFC53D5D),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (docs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    context.tr('No videos found for selected filter.'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _GeneralVideoAdminCard(doc: docs[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GeneralVideoAdminCard extends StatelessWidget {
  const _GeneralVideoAdminCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  DocumentReference<Map<String, dynamic>> get _ref => doc.reference;

  void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _audit({
    required String action,
    required String before,
    required String after,
    String? reason,
  }) {
    return FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'general_video',
      'entityId': doc.id,
      'contestId': '',
      'participantId': (doc.data()['userId'] ?? '').toString(),
      'action': action,
      'beforeStatus': before,
      'afterStatus': after,
      'reason': reason ?? '',
      'actorId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _notify(String title, String message) async {
    final userId = (doc.data()['userId'] ?? '').toString();
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'message': message,
          'contestId': '',
          'submissionId': doc.id,
          'read': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> _approve(BuildContext context) async {
    final before = (doc.data()['status'] ?? 'pending').toString();
    final title = context.tr('Video Approved');
    final message = context.tr('Your video was approved and is now public.');
    final done = context.tr('Video approved.');
    await _ref.update({
      'status': 'approved',
      'rejectionReason': null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'moderatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _audit(action: 'approve', before: before, after: 'approved');
    await _notify(title, message);
    if (context.mounted) _snack(context, done);
  }

  Future<void> _reject(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Reject Video')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: dialogContext.tr('Reason (required)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Cancel')),
          ),
          TextButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(dialogContext, value);
            },
            child: Text(dialogContext.tr('Reject')),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty || !context.mounted) return;

    final before = (doc.data()['status'] ?? 'pending').toString();
    final title = context.tr('Video Rejected');
    final message =
        '${context.tr('Your video was rejected.')} ${context.tr('Reason')}: $reason';
    final done = context.tr('Video rejected.');
    await _ref.update({
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'moderatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _audit(
      action: 'reject',
      before: before,
      after: 'rejected',
      reason: reason,
    );
    await _notify(title, message);
    if (context.mounted) _snack(context, done);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Delete Video')),
        content: Text(
          dialogContext.tr('Are you sure you want to delete this video?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _audit(
      action: 'delete',
      before: (doc.data()['status'] ?? '').toString(),
      after: 'deleted',
    );
    await GeneralVideoService().delete(GeneralVideo.fromDoc(doc));
  }

  Future<void> _block(BuildContext context, String name) async {
    final userId = (doc.data()['userId'] ?? '').toString();
    if (userId.isEmpty) return;
    await showBlockParticipantDialog(
      context: context,
      blockedUserId: userId,
      submissionId: doc.id,
      participantName: name,
    );
  }

  void _watch(BuildContext context, String videoUrl, String title) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Video unavailable.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SimpleVideoPlayerScreen(videoUrl: videoUrl, title: title),
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    String name,
    String statusLabel,
    Color statusColor,
  ) async {
    final data = doc.data();
    final caption = (data['caption'] ?? '').toString();
    final reason = (data['rejectionReason'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(name, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(
              dialogContext.tr('Type'),
              dialogContext.tr('General'),
              const Color(0xFF4DA3FF),
            ),
            _line(dialogContext.tr('Status'), statusLabel, statusColor),
            if (createdAt != null)
              _line(
                dialogContext.tr('Date'),
                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                AppColors.textMuted,
              ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(caption, style: const TextStyle(color: AppColors.textMuted)),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${dialogContext.tr('Reason')}: $reason',
                style: const TextStyle(color: Color(0xFFFF7A93)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Close')),
          ),
        ],
      ),
    );
  }

  Widget _buildName(
    BuildContext context,
    String storedUserName,
    String userId,
  ) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    if (storedUserName.isNotEmpty) {
      return Text(
        storedUserName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    if (userId.isEmpty) {
      return Text(context.tr('Unknown User'), style: style);
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnap) {
        final liveName = (userSnap.data?.data()?['displayName'] ?? '')
            .toString();
        return Text(
          liveName.isNotEmpty ? liveName : context.tr('Unknown User'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final status = (data['status'] ?? 'pending').toString();
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString();
    final storedUserName = (data['userName'] ?? '').toString();
    final userId = (data['userId'] ?? '').toString();

    final (statusColor, statusLabel) = switch (status) {
      'approved' => (const Color(0xFF2DAF6F), context.tr('Approved')),
      'rejected' => (const Color(0xFFC53D5D), context.tr('Rejected')),
      _ => (AppColors.sunset, context.tr('Pending')),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _watch(context, videoUrl, storedUserName),
            child: Container(
              width: 64,
              height: 84,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: thumbnailUrl.isEmpty
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.cardSoft, AppColors.deepSpace],
                      )
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl.isNotEmpty)
                    Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.cardSoft),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.hotPink,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildName(context, storedUserName, userId),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.card,
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            onSelected: (value) {
              switch (value) {
                case 'watch':
                  _watch(context, videoUrl, storedUserName);
                  break;
                case 'details':
                  _showDetails(
                    context,
                    storedUserName,
                    statusLabel,
                    statusColor,
                  );
                  break;
                case 'approve':
                  _approve(context);
                  break;
                case 'reject':
                  _reject(context);
                  break;
                case 'block':
                  _block(context, storedUserName);
                  break;
                case 'delete':
                  _delete(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (videoUrl.isNotEmpty)
                PopupMenuItem(
                  value: 'watch',
                  child: Text(context.tr('Watch Video')),
                ),
              PopupMenuItem(
                value: 'details',
                child: Text(context.tr('View Details')),
              ),
              if (status != 'approved')
                PopupMenuItem(
                  value: 'approve',
                  child: Text(context.tr('Approve')),
                ),
              if (status != 'rejected')
                PopupMenuItem(
                  value: 'reject',
                  child: Text(context.tr('Reject')),
                ),
              PopupMenuItem(value: 'block', child: Text(context.tr('Block'))),
              PopupMenuItem(value: 'delete', child: Text(context.tr('Delete'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
