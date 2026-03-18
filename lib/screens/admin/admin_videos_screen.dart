import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key, this.contestIdFilter, this.customTitle});

  final String? contestIdFilter;
  final String? customTitle;

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  bool _sortDesc = true;
  String _statusFilter = 'all';
  static const List<String> _statusOptions = <String>[
    'all',
    'pending',
    'under_review',
    'approved',
    'rejected',
    'removed',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final stream = FirebaseFirestore.instance
        .collectionGroup('submissions')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customTitle ?? context.tr('Videos Moderation')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _search = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr('Search contest or user'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Sort By Created Date'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('Newest First')),
                            selected: _sortDesc,
                            onSelected: (_) => setState(() => _sortDesc = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(context.tr('Oldest First')),
                            selected: !_sortDesc,
                            onSelected: (_) =>
                                setState(() => _sortDesc = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Filter By Status'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusOptions.map((status) {
                            final selected = _statusFilter == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_toStatusLabel(context, status)),
                                selected: selected,
                                onSelected: (_) =>
                                    setState(() => _statusFilter = status),
                                selectedColor: _statusColor(
                                  status,
                                ).withOpacity(0.2),
                                checkmarkColor: _statusColor(status),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUid)
                      .get(),
                  builder: (context, roleSnap) {
                    if (!roleSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final role = (roleSnap.data!.data()?['role'] ?? '')
                        .toString()
                        .toLowerCase();
                    final isSuperAdmin =
                        role == 'super_admin' || role == 'superadmin';

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs =
                            snapshot.data!.docs.where((d) {
                              if (isSuperAdmin) return true;
                              final adminId = (d.data()['contestAdminId'] ?? '')
                                  .toString();
                              return adminId == currentUid;
                            }).toList()..sort((a, b) {
                              final at =
                                  (a.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              final bt =
                                  (b.data()['createdAt'] as Timestamp?)
                                      ?.millisecondsSinceEpoch ??
                                  0;
                              return _sortDesc
                                  ? bt.compareTo(at)
                                  : at.compareTo(bt);
                            });

                        final total = docs.length;
                        final pendingCount = docs
                            .where(
                              (d) =>
                                  (d.data()['status'] ?? 'pending')
                                      .toString() ==
                                  'pending',
                            )
                            .length;
                        final underReviewCount = docs
                            .where(
                              (d) =>
                                  (d.data()['status'] ?? 'pending')
                                      .toString() ==
                                  'under_review',
                            )
                            .length;
                        final approvedCount = docs
                            .where(
                              (d) =>
                                  (d.data()['status'] ?? 'pending')
                                      .toString() ==
                                  'approved',
                            )
                            .length;
                        final rejectedCount = docs
                            .where(
                              (d) =>
                                  (d.data()['status'] ?? 'pending')
                                      .toString() ==
                                  'rejected',
                            )
                            .length;

                        final removedCount = docs
                            .where(
                              (d) =>
                                  (d.data()['status'] ?? 'pending')
                                      .toString() ==
                                  'removed',
                            )
                            .length;

                        final filtered = docs.where((doc) {
                          final status = (doc.data()['status'] ?? 'pending')
                              .toString();
                          final contestId = (doc.data()['contestId'] ?? '')
                              .toString();
                          if (widget.contestIdFilter != null &&
                              widget.contestIdFilter!.trim().isNotEmpty &&
                              contestId != widget.contestIdFilter) {
                            return false;
                          }
                          if (_statusFilter != 'all' && status != _statusFilter)
                            return false;
                          if (_search.isEmpty) return true;
                          final contestIdLc = contestId.toLowerCase();
                          final userId = (doc.data()['userId'] ?? '')
                              .toString()
                              .toLowerCase();
                          return contestIdLc.contains(_search) ||
                              userId.contains(_search);
                        }).toList();

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final crossAxisCount = width >= 980
                                      ? 4
                                      : width >= 760
                                      ? 3
                                      : 2;
                                  final ratio = width >= 980
                                      ? 2.1
                                      : width >= 760
                                      ? 1.7
                                      : 1.35;
                                  return GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    childAspectRatio: ratio,
                                    children: [
                                      _StatCard(
                                        label: context.tr('Total'),
                                        value: total.toString(),
                                        color: AppColors.hotPink,
                                        icon: Icons.video_collection,
                                      ),
                                      _StatCard(
                                        label: context.tr('Pending'),
                                        value: pendingCount.toString(),
                                        color: AppColors.sunset,
                                        icon: Icons.hourglass_top,
                                      ),
                                      _StatCard(
                                        label: context.tr('Under Review'),
                                        value: underReviewCount.toString(),
                                        color: const Color(0xFF5AB4FF),
                                        icon: Icons.rule_folder,
                                      ),
                                      _StatCard(
                                        label: context.tr('Approved'),
                                        value: approvedCount.toString(),
                                        color: const Color(0xFF2DAF6F),
                                        icon: Icons.check_circle,
                                      ),
                                      _StatCard(
                                        label: context.tr('Rejected'),
                                        value: rejectedCount.toString(),
                                        color: const Color(0xFFC53D5D),
                                        icon: Icons.cancel,
                                      ),
                                      _StatCard(
                                        label: context.tr('Removed'),
                                        value: removedCount.toString(),
                                        color: const Color(0xFF9B8AA8),
                                        icon: Icons.remove_circle,
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                            if (filtered.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(context.tr('No matching videos.')),
                              );
                            }
                            final doc = filtered[index - 1];
                            final data = doc.data();
                            final status = (data['status'] ?? 'pending')
                                .toString();
                            final contestId = (data['contestId'] ?? '')
                                .toString();
                            final userId = (data['userId'] ?? '').toString();
                            final videoUrl = (data['videoUrl'] ?? '')
                                .toString();
                            final reportReason =
                                (data['sponsorReportReason'] ?? '').toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: AppColors.hotPink.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.video_file,
                                          color: AppColors.hotPink,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FutureBuilder<_SubmissionMeta>(
                                          future: _loadMeta(
                                            contestId: contestId,
                                            userId: userId,
                                          ),
                                          builder: (context, metaSnap) {
                                            final fallbackContestName =
                                                (data['contestTitle'] ??
                                                        data['contestName'] ??
                                                        '')
                                                    .toString();
                                            final fallbackUserName =
                                                (data['userName'] ??
                                                        data['participantName'] ??
                                                        '')
                                                    .toString();
                                            final contestName =
                                                metaSnap.data?.contestName ??
                                                (fallbackContestName.isNotEmpty
                                                    ? fallbackContestName
                                                    : context.tr(
                                                        'Unknown Contest',
                                                      ));
                                            final userName =
                                                metaSnap.data?.userName ??
                                                (fallbackUserName.isNotEmpty
                                                    ? fallbackUserName
                                                    : context.tr(
                                                        'Unknown User',
                                                      ));
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${context.tr('Contest')}: $contestName',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleSmall,
                                                ),
                                                Text(
                                                  '${context.tr('User')}: $userName',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusColor(
                                            status,
                                          ).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(
                                    color: AppColors.border,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: videoUrl.isEmpty
                                        ? null
                                        : () async {
                                            if (!context.mounted) return;
                                            await showDialog<void>(
                                              context: context,
                                              barrierDismissible: true,
                                              builder: (_) =>
                                                  _VideoPlayerDialog(
                                                    videoUrl: videoUrl,
                                                  ),
                                            );
                                          },
                                    icon: const Icon(Icons.play_circle_fill),
                                    label: Text(context.tr('Watch Video')),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.cardSoft,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _showDetails(
                                      context,
                                      doc.reference,
                                      data,
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: Text(context.tr('View Details')),
                                  ),
                                  if (status == 'under_review' &&
                                      reportReason.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${context.tr('Sponsor report')}: $reportReason',
                                      style: const TextStyle(
                                        color: AppColors.sunset,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: doc.reference
                                        .collection('sponsor_comments')
                                        .orderBy('createdAt', descending: true)
                                        .limit(1)
                                        .snapshots(),
                                    builder: (context, commentSnap) {
                                      if (!commentSnap.hasData ||
                                          commentSnap.data!.docs.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final latest =
                                          commentSnap.data!.docs.first;
                                      final c = (latest.data()['comment'] ?? '')
                                          .toString();
                                      final by =
                                          (latest.data()['sponsorName'] ??
                                                  'Sponsor')
                                              .toString();
                                      if (c.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          '${context.tr('Sponsor comment')} ($by): $c',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (status == 'pending' ||
                                      status == 'under_review') ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _approve(
                                              context,
                                              doc.reference,
                                              data,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF2DAF6F,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(context.tr('Approve')),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _reject(
                                              context,
                                              doc.reference,
                                              data,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFC53D5D,
                                              ),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text(context.tr('Reject')),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (status == 'approved' ||
                                      status == 'under_review') ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: () => _removeAfterPublish(
                                        context,
                                        doc.reference,
                                        data,
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                      label: Text(context.tr('Remove Video')),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final now = Timestamp.fromDate(DateTime.now());
    await ref.update({
      'status': 'approved',
      'rejectionReason': null,
      'sponsorReportReason': null,
      'updatedAt': now,
      'moderatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _writeAuditLog(
      action: 'approve',
      beforeStatus: (data['status'] ?? 'pending').toString(),
      afterStatus: 'approved',
      submissionRef: ref,
      data: data,
    );
    await _notifyParticipant(
      userId: (data['userId'] ?? '').toString(),
      title: 'Video Approved',
      message: 'Your video was approved and is now public.',
      contestId: (data['contestId'] ?? '').toString(),
      submissionId: ref.id,
    );
    _snack(context, context.tr('Video approved.'));
  }

  Future<void> _reject(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Reject Video')),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: context.tr('Reason (required)'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            TextButton(
              onPressed: () {
                final value = reasonController.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(context, value);
              },
              child: Text(context.tr('Reject')),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    final now = Timestamp.fromDate(DateTime.now());
    await ref.update({
      'status': 'rejected',
      'rejectionReason': reason,
      'allowReupload': true,
      'updatedAt': now,
      'moderatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _writeAuditLog(
      action: 'reject',
      reason: reason,
      beforeStatus: (data['status'] ?? 'pending').toString(),
      afterStatus: 'rejected',
      submissionRef: ref,
      data: data,
    );
    await _notifyParticipant(
      userId: (data['userId'] ?? '').toString(),
      title: context.tr('Video Rejected'),
      message: '${context.tr('Your video was rejected.')} ${context.tr('Reason')}: $reason',
      contestId: (data['contestId'] ?? '').toString(),
      submissionId: ref.id,
    );
    _snack(context, context.tr('Video rejected.'));
  }

  Future<void> _removeAfterPublish(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Video')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: context.tr('Reason (required)'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(context, value);
            },
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    await ref.update({
      'status': 'removed',
      'removedReason': reason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'moderatedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _writeAuditLog(
      action: 'remove',
      reason: reason,
      beforeStatus: (data['status'] ?? '').toString(),
      afterStatus: 'removed',
      submissionRef: ref,
      data: data,
    );
    await _notifyParticipant(
      userId: (data['userId'] ?? '').toString(),
      title: context.tr('Video Removed'),
      message: '${context.tr('Your video was removed.')} ${context.tr('Reason')}: $reason',
      contestId: (data['contestId'] ?? '').toString(),
      submissionId: ref.id,
    );
    _snack(context, context.tr('Video removed.'));
  }

  Future<void> _showDetails(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final meta = await _loadMeta(
      contestId: (data['contestId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _VideoDetailsDialog(
        contestName: meta.contestName,
        userName: meta.userName,
        status: (data['status'] ?? 'pending').toString(),
        votes: ((data['voteCount'] ?? 0) as num).toInt(),
        shares: ((data['shareCount'] ?? 0) as num).toInt(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        rejectionReason: (data['rejectionReason'] ?? '').toString(),
        removedReason: (data['removedReason'] ?? '').toString(),
        contestAdminName: (data['contestAdminName'] ?? '').toString(),
      ),
    );
  }

  Future<void> _writeAuditLog({
    required String action,
    required String beforeStatus,
    required String afterStatus,
    required DocumentReference<Map<String, dynamic>> submissionRef,
    required Map<String, dynamic> data,
    String? reason,
  }) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'entityType': 'submission',
      'entityId': submissionRef.id,
      'contestId': (data['contestId'] ?? '').toString(),
      'participantId': (data['userId'] ?? '').toString(),
      'action': action,
      'beforeStatus': beforeStatus,
      'afterStatus': afterStatus,
      'reason': reason ?? '',
      'actorId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _notifyParticipant({
    required String userId,
    required String title,
    required String message,
    required String contestId,
    required String submissionId,
  }) async {
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': title,
          'message': message,
          'contestId': contestId,
          'submissionId': submissionId,
          'read': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<_SubmissionMeta> _loadMeta({
    required String contestId,
    required String userId,
  }) async {
    final contestDoc = await FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .get();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final contestName = (contestDoc.data()?['title'] ?? '').toString().trim();
    final userName =
        (userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? userId)
            .toString()
            .trim();
    return _SubmissionMeta(
      contestName: contestName.isEmpty ? 'Unknown Contest' : contestName,
      userName: userName.isEmpty ? 'Unknown User' : userName,
    );
  }

  void _snack(BuildContext context, String message) {
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
      case 'pending':
        return AppColors.sunset;
      case 'all':
        return AppColors.hotPink;
      default:
        return AppColors.sunset;
    }
  }

  String _toStatusLabel(BuildContext context, String status) {
    switch (status) {
      case 'all':
        return context.tr('All');
      case 'pending':
        return context.tr('Pending');
      case 'under_review':
        return context.tr('Under Review');
      case 'approved':
        return context.tr('Approved');
      case 'rejected':
        return context.tr('Rejected');
      case 'removed':
        return context.tr('Removed');
      default:
        return status;
    }
  }
}

class _VideoDetailsDialog extends StatelessWidget {
  const _VideoDetailsDialog({
    required this.contestName,
    required this.userName,
    required this.status,
    required this.votes,
    required this.shares,
    required this.createdAt,
    required this.updatedAt,
    required this.rejectionReason,
    required this.removedReason,
    required this.contestAdminName,
  });

  final String contestName;
  final String userName;
  final String status;
  final int votes;
  final int shares;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String rejectionReason;
  final String removedReason;
  final String contestAdminName;

  String _fmt(DateTime? date) {
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry(context.tr('Contest'), contestName),
      MapEntry(context.tr('User'), userName),
      MapEntry(context.tr('Status'), status),
      MapEntry(context.tr('Total Votes'), votes.toString()),
      MapEntry(context.tr('Total Shares'), shares.toString()),
      MapEntry(context.tr('Contest Admin'), contestAdminName.isEmpty ? '-' : contestAdminName),
      MapEntry(context.tr('Created At'), _fmt(createdAt)),
      MapEntry(context.tr('Updated At'), _fmt(updatedAt)),
      if (rejectionReason.trim().isNotEmpty)
        MapEntry(context.tr('Rejection Reason'), rejectionReason),
      if (removedReason.trim().isNotEmpty)
        MapEntry(context.tr('Removed Reason'), removedReason),
    ];

    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Video Details'),
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: rows.map((row) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              row.key,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Text(
                              row.value,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionMeta {
  const _SubmissionMeta({required this.contestName, required this.userName});

  final String contestName;
  final String userName;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      padding: const EdgeInsets.all(10),
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
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

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
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
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final playerWidth = maxWidth > 720 ? 720.0 : maxWidth;
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Video Preview'),
                    style: const TextStyle(
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
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(context.tr('Unable to load video.')),
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        width: playerWidth,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: VideoPlayer(_controller),
                          ),
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
