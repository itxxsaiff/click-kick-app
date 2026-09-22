import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/general_video_service.dart';
import '../../theme/app_colors.dart';
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
        final docs =
            snapshot.data!.docs.where((doc) {
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

        if (docs.isEmpty) {
          return Center(
            child: Text(
              context.tr('No videos found for selected filter.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _GeneralVideoAdminCard(doc: docs[i]),
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

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final status = (data['status'] ?? 'pending').toString();
    final videoUrl = (data['videoUrl'] ?? '').toString();
    final userName = (data['userName'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final reason = (data['rejectionReason'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final (statusColor, statusLabel) = switch (status) {
      'approved' => (const Color(0xFF2DAF6F), context.tr('Approved')),
      'rejected' => (const Color(0xFFC53D5D), context.tr('Rejected')),
      _ => (AppColors.sunset, context.tr('Pending')),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: videoUrl.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SimpleVideoPlayerScreen(
                            videoUrl: videoUrl,
                            title: userName,
                          ),
                        ),
                      ),
                child: Container(
                  width: 92,
                  height: 118,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.cardSoft, AppColors.deepSpace],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.hotPink,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(context.tr('User'), userName, Colors.white),
                    _line(
                      context.tr('Type'),
                      context.tr('General'),
                      const Color(0xFF4DA3FF),
                    ),
                    _line(context.tr('Status'), statusLabel, statusColor),
                    if (createdAt != null)
                      _line(
                        context.tr('Date'),
                        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}',
                        AppColors.textMuted,
                      ),
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (status == 'rejected' && reason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${context.tr('Reason')}: $reason',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFF7A93),
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (status != 'approved')
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approve(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF12B76A),
                    ),
                    child: Text(context.tr('Approve')),
                  ),
                ),
              if (status != 'approved' && status != 'rejected')
                const SizedBox(width: 10),
              if (status != 'rejected')
                Expanded(
                  child: FilledButton(
                    onPressed: () => _reject(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF04466),
                    ),
                    child: Text(context.tr('Reject')),
                  ),
                ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: context.tr('Delete'),
                onPressed: () => _delete(context),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textMuted,
                ),
              ),
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
