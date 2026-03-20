import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class ContestVideoReviewScreen extends StatelessWidget {
  const ContestVideoReviewScreen({
    super.key,
    required this.contestId,
    this.onEditContest,
  });

  final String contestId;
  final VoidCallback? onEditContest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Contest Video Review')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('contests')
            .doc(contestId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data();
          if (data == null) {
            return Center(child: Text(context.tr('Contest not found.')));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ContestVideoReviewSection(
                contestId: contestId,
                contestData: data,
                isSponsor: false,
                onEditContest: onEditContest,
              ),
            ],
          );
        },
      ),
    );
  }
}

class ContestVideoReviewSection extends StatefulWidget {
  const ContestVideoReviewSection({
    super.key,
    required this.contestId,
    required this.contestData,
    required this.isSponsor,
    this.onEditContest,
  });

  final String contestId;
  final Map<String, dynamic> contestData;
  final bool isSponsor;
  final VoidCallback? onEditContest;

  @override
  State<ContestVideoReviewSection> createState() =>
      _ContestVideoReviewSectionState();
}

class _ContestVideoReviewSectionState extends State<ContestVideoReviewSection> {
  final TextEditingController _noteController = TextEditingController();
  bool _sending = false;
  bool _approving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _reviewStatusLabel(BuildContext context, String status) {
    switch (status) {
      case 'pending_upload':
        return context.tr('Waiting Upload');
      case 'pending':
        return context.tr('Pending Sponsor Review');
      case 'approved':
        return context.tr('Approved');
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Future<String> _senderName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return widget.isSponsor ? context.tr('Sponsor') : context.tr('Admin');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      final name = (data?['displayName'] ?? user.displayName ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return widget.isSponsor ? context.tr('Sponsor') : context.tr('Admin');
  }

  Future<void> _sendNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _sending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('review_messages')
          .add({
        'senderId': user.uid,
        'senderName': await _senderName(),
        'senderRole': widget.isSponsor ? 'sponsor' : 'admin',
        'message': text,
        'type': 'note',
        'createdAt': now,
      });
      await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .set({
        'updatedAt': now,
        'lastReviewMessageAt': now,
      }, SetOptions(merge: true));
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Review note sent.'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _approveContestVideo() async {
    if (_approving) return;
    final applicationId =
        (widget.contestData['sponsorshipApplicationId'] ?? '').toString();
    setState(() => _approving = true);
    try {
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('contests').doc(widget.contestId).set({
        'status': 'live',
        'sponsorVideoApprovalStatus': 'approved',
        'sponsorVideoReviewedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('review_messages')
          .add({
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'senderName': await _senderName(),
        'senderRole': 'sponsor',
        'message': context.tr('Official contest video approved by sponsor. Contest is now live.'),
        'type': 'system',
        'createdAt': now,
      });
      if (applicationId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('sponsorship_applications')
            .doc(applicationId)
            .set({
          'applicationStatus': 'live',
          'updatedAt': now,
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Contest video approved. Contest is now live.'))),
      );
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _openVideoDialog(String videoUrl) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ContestReviewVideoDialog(videoUrl: videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contestVideoUrl = (widget.contestData['contestVideoUrl'] ?? '').toString();
    final reviewStatus =
        (widget.contestData['sponsorVideoApprovalStatus'] ?? 'pending_upload')
            .toString();
    final canReview = contestVideoUrl.isNotEmpty;
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 760;
    final notesMinHeight = isCompact ? 150.0 : screenHeight * 0.24;
    final notesMaxHeight = isCompact ? 240.0 : screenHeight * 0.40;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Official Contest Video'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.hotPink.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _reviewStatusLabel(context, reviewStatus),
                  style: const TextStyle(
                    color: AppColors.hotPink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            canReview
                ? context.tr('Review the uploaded contest video, send notes, and approve when it is ready to go live.')
                : context.tr('Waiting for admin to upload official contest video.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: canReview ? () => _openVideoDialog(contestVideoUrl) : null,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(context.tr('Watch')),
              ),
              if (!widget.isSponsor && widget.onEditContest != null)
                OutlinedButton.icon(
                  onPressed: widget.onEditContest,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('Edit Contest')),
                ),
              if (widget.isSponsor && reviewStatus == 'pending' && canReview)
                FilledButton.icon(
                  onPressed: _approving ? null : _approveContestVideo,
                  icon: const Icon(Icons.check_circle),
                  label: Text(context.tr('Approve Video')),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('Review Notes'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(
              minHeight: notesMinHeight,
              maxHeight: notesMaxHeight,
            ),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('contests')
                  .doc(widget.contestId)
                  .collection('review_messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('No review notes yet.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final senderRole = (d['senderRole'] ?? '').toString();
                    final isMine = senderRole == (widget.isSponsor ? 'sponsor' : 'admin');
                    final senderName = (d['senderName'] ?? context.tr('Admin')).toString();
                    final message = (d['message'] ?? '').toString();
                    final type = (d['type'] ?? 'note').toString();
                    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: type == 'system'
                                ? AppColors.hotPink.withOpacity(0.10)
                                : (isMine ? AppColors.hotPink.withOpacity(0.16) : AppColors.deepSpace.withOpacity(0.35)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(message),
                              if (createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: isCompact ? 2 : 3,
            maxLines: isCompact ? 3 : 4,
            enabled: canReview && !_sending,
            decoration: InputDecoration(
              hintText: widget.isSponsor
                  ? context.tr('Send note to admin about this contest video...')
                  : context.tr('Send note to sponsor about this contest video...'),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: canReview && !_sending ? _sendNote : null,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(context.tr('Send Note')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestReviewVideoDialog extends StatefulWidget {
  const _ContestReviewVideoDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_ContestReviewVideoDialog> createState() => _ContestReviewVideoDialogState();
}

class _ContestReviewVideoDialogState extends State<_ContestReviewVideoDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Official Contest Video'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.black,
                  child: _ready
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(child: VideoPlayer(_controller)),
                            IconButton.filled(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
