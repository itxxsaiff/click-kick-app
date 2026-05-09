import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/l10n.dart';
import '../../services/participant_report_service.dart';
import '../../theme/app_colors.dart';

class AdminParticipantsScreen extends StatefulWidget {
  const AdminParticipantsScreen({super.key});

  @override
  State<AdminParticipantsScreen> createState() =>
      _AdminParticipantsScreenState();
}

class _AdminParticipantsScreenState extends State<AdminParticipantsScreen> {
  final _searchController = TextEditingController();
  final _reportService = ParticipantReportService();
  String _search = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'participant')
        .snapshots();
    final submissionsStream = FirebaseFirestore.instance
        .collectionGroup('submissions')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Participants')),
            Text(
              context.tr('Creators list'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: submissionsStream,
                builder: (context, submissionsSnapshot) {
                  if (!submissionsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final uploadCounts = <String, int>{};
                  for (final submission in submissionsSnapshot.data!.docs) {
                    final userId = (submission.data()['userId'] ?? '')
                        .toString();
                    if (userId.isEmpty) continue;
                    uploadCounts[userId] = (uploadCounts[userId] ?? 0) + 1;
                  }

                  final docs = usersSnapshot.data!.docs.toList()
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

                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    final isBlocked =
                        (data['accountStatus'] ?? 'active').toString() ==
                        'disabled';
                    if (_filter == 'blocked' && !isBlocked) return false;
                    if (_filter == 'active' && isBlocked) return false;
                    if (_search.isEmpty) return true;
                    final name = (data['displayName'] ?? 'user')
                        .toString()
                        .toLowerCase();
                    final email = (data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    final phone = (data['phoneE164'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_search) ||
                        email.contains(_search) ||
                        phone.contains(_search);
                  }).toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(
                                  () => _search = v.trim().toLowerCase(),
                                ),
                                decoration: InputDecoration(
                                  hintText: context.tr('Search participants'),
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
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF18152A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: PopupMenuButton<String>(
                                tooltip: context.tr('Filter'),
                                initialValue: _filter,
                                color: AppColors.card,
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  color: Colors.white,
                                ),
                                onSelected: (value) =>
                                    setState(() => _filter = value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'all',
                                    child: Text(context.tr('All')),
                                  ),
                                  PopupMenuItem(
                                    value: 'active',
                                    child: Text(context.tr('Active')),
                                  ),
                                  PopupMenuItem(
                                    value: 'blocked',
                                    child: Text(context.tr('Blocked')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  context.tr('No matching participants.'),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                itemCount: filtered.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  if (index == filtered.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 12,
                                      ),
                                      child: Center(
                                        child: Text(
                                          context.tr('No more participants'),
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final doc = filtered[index];
                                  final data = doc.data();
                                  final name = (data['displayName'] ?? 'User')
                                      .toString();
                                  final email = (data['email'] ?? '')
                                      .toString();
                                  final phone = (data['phoneE164'] ?? '')
                                      .toString();
                                  final photoUrl = (data['photoUrl'] ?? '')
                                      .toString();
                                  final isBlocked =
                                      (data['accountStatus'] ?? 'active')
                                          .toString() ==
                                      'disabled';
                                  final uploads = uploadCounts[doc.id] ?? 0;
                                  final statusColor = isBlocked
                                      ? const Color(0xFFD64B6A)
                                      : const Color(0xFF38E27B);

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF151324),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: AppColors.cardSoft,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            image: photoUrl.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(
                                                      photoUrl,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                            gradient: photoUrl.isEmpty
                                                ? const LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Color(0xFF4B1A7E),
                                                      Color(0xFF12101C),
                                                    ],
                                                  )
                                                : null,
                                          ),
                                          child: photoUrl.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    name.isEmpty
                                                        ? 'U'
                                                        : name
                                                              .trim()
                                                              .split(
                                                                RegExp(r'\s+'),
                                                              )
                                                              .take(2)
                                                              .map(
                                                                (e) => e[0]
                                                                    .toUpperCase(),
                                                              )
                                                              .join(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 19,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor
                                                          .withOpacity(0.16),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      context.tr(
                                                        isBlocked
                                                            ? 'Blocked'
                                                            : 'Active',
                                                      ),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                email,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 6,
                                                children: [
                                                  _ParticipantMeta(
                                                    icon: Icons
                                                        .video_library_outlined,
                                                    label: 'Uploads: $uploads',
                                                  ),
                                                  if (phone.isNotEmpty)
                                                    _ParticipantMeta(
                                                      icon:
                                                          Icons.phone_outlined,
                                                      label: phone,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.more_vert,
                                            color: AppColors.textMuted,
                                          ),
                                          onSelected: (value) async {
                                            if (value == 'details') {
                                              await _openDetails(
                                                participantId: doc.id,
                                                data: data,
                                              );
                                            } else if (value == 'report') {
                                              await _openParticipantReport(
                                                participantId: doc.id,
                                                data: data,
                                              );
                                            } else if (value == 'block') {
                                              await _setParticipantStatus(
                                                participantId: doc.id,
                                                status: 'disabled',
                                              );
                                            } else if (value == 'unblock') {
                                              await _setParticipantStatus(
                                                participantId: doc.id,
                                                status: 'active',
                                              );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'details',
                                              child: Text(
                                                context.tr('View Details'),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'report',
                                              child: Text(
                                                context.tr(
                                                  'Participant Report',
                                                ),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: isBlocked
                                                  ? 'unblock'
                                                  : 'block',
                                              child: Text(
                                                context.tr(
                                                  isBlocked
                                                      ? 'Unblock Participant'
                                                      : 'Block Participant',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
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

  Future<void> _setParticipantStatus({
    required String participantId,
    required String status,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(participantId)
        .set({
          'accountStatus': status,
          'updatedAt': DateTime.now().toUtc(),
          if (status == 'disabled') 'accessBlockedAt': DateTime.now().toUtc(),
          if (status == 'active') 'accessBlockedAt': FieldValue.delete(),
        }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            status == 'disabled'
                ? 'Participant access blocked.'
                : 'Participant access restored.',
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails({
    required String participantId,
    required Map<String, dynamic> data,
  }) async {
    final stats = await _loadParticipantStats(participantId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ParticipantDetailScreen(
          participantId: participantId,
          data: data,
          stats: stats,
          onOpenReport: () =>
              _openParticipantReport(participantId: participantId, data: data),
        ),
      ),
    );
  }

  Future<void> _openAllParticipantsReport() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'participant')
        .get();
    final submissionsSnap = await FirebaseFirestore.instance
        .collectionGroup('submissions')
        .get();

    final byParticipant =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in submissionsSnap.docs) {
      final participantId = (doc.data()['userId'] ?? '').toString();
      if (participantId.isEmpty) continue;
      byParticipant.putIfAbsent(participantId, () => []).add(doc);
    }

    final rows = usersSnap.docs.map((doc) {
      final data = doc.data();
      final submissions = byParticipant[doc.id] ?? const [];
      final joinedContests = submissions
          .map((e) => (e.data()['contestId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;
      final approved = submissions
          .where((e) => (e.data()['status'] ?? '').toString() == 'approved')
          .length;
      final rejected = submissions
          .where((e) => (e.data()['status'] ?? '').toString() == 'rejected')
          .length;
      final pending = submissions
          .where(
            (e) => (e.data()['status'] ?? 'pending').toString() == 'pending',
          )
          .length;
      return ParticipantSummaryRow(
        name: (data['displayName'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        phone: (data['phoneE164'] ?? '').toString(),
        joinedContests: joinedContests,
        approvedCount: approved,
        rejectedCount: rejected,
        pendingCount: pending,
      );
    }).toList();

    final bytes = await _reportService.buildAllParticipantsReport(rows: rows);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('All Participants Report'),
          bytes: bytes,
          filename: 'all-participants-report.pdf',
        ),
      ),
    );
  }

  Future<void> _openParticipantReport({
    required String participantId,
    required Map<String, dynamic> data,
  }) async {
    final stats = await _loadParticipantStats(participantId);
    final bytes = await _reportService.buildSingleParticipantReport(
      participantName: (data['displayName'] ?? '').toString(),
      participantEmail: (data['email'] ?? '').toString(),
      participantPhone: (data['phoneE164'] ?? '').toString(),
      joinedContests: stats.joinedContests,
      approvedCount: stats.approvedCount,
      rejectedCount: stats.rejectedCount,
      pendingCount: stats.pendingCount,
      contests: stats.contests,
    );
    if (!mounted) return;
    final safeName = (data['displayName'] ?? 'participant')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('Participant Report'),
          bytes: bytes,
          filename: '$safeName-participant-report.pdf',
        ),
      ),
    );
  }

  Future<_ParticipantStats> _loadParticipantStats(String participantId) async {
    final submissionsSnap = await FirebaseFirestore.instance
        .collectionGroup('submissions')
        .get();
    final submissions = submissionsSnap.docs.where((doc) {
      return (doc.data()['userId'] ?? '').toString() == participantId;
    }).toList();

    final contestIds = submissions
        .map((doc) => (doc.data()['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final contestNames = await _loadContestMap(contestIds);

    String dateText(Timestamp? ts) {
      if (ts == null) return '-';
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final rows = submissions.map((doc) {
      final data = doc.data();
      final contestId = (data['contestId'] ?? '').toString();
      final status = (data['status'] ?? 'pending').toString();
      final reason = (data['rejectionReason'] ?? '').toString();
      return ParticipantContestRow(
        contestName: contestNames[contestId] ?? contestId,
        status: status,
        rejectionReason: reason.isEmpty ? '-' : reason,
        createdAtText: dateText(data['createdAt'] as Timestamp?),
      );
    }).toList()..sort((a, b) => b.createdAtText.compareTo(a.createdAtText));

    return _ParticipantStats(
      joinedContests: contestIds.length,
      approvedCount: submissions
          .where((doc) => (doc.data()['status'] ?? '').toString() == 'approved')
          .length,
      rejectedCount: submissions
          .where((doc) => (doc.data()['status'] ?? '').toString() == 'rejected')
          .length,
      pendingCount: submissions
          .where(
            (doc) =>
                (doc.data()['status'] ?? 'pending').toString() == 'pending',
          )
          .length,
      contests: rows,
    );
  }

  Future<Map<String, String>> _loadContestMap(List<String> ids) async {
    if (ids.isEmpty) return <String, String>{};
    final map = <String, String>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await FirebaseFirestore.instance
          .collection('contests')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        map[doc.id] = (doc.data()['title'] ?? doc.id).toString();
      }
    }
    return map;
  }
}

class _ParticipantStats {
  const _ParticipantStats({
    required this.joinedContests,
    required this.approvedCount,
    required this.rejectedCount,
    required this.pendingCount,
    required this.contests,
  });

  final int joinedContests;
  final int approvedCount;
  final int rejectedCount;
  final int pendingCount;
  final List<ParticipantContestRow> contests;
}

class _ParticipantDetailScreen extends StatelessWidget {
  const _ParticipantDetailScreen({
    required this.participantId,
    required this.data,
    required this.stats,
    required this.onOpenReport,
  });

  final String participantId;
  final Map<String, dynamic> data;
  final _ParticipantStats stats;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] ?? 'User').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phoneE164'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Participant Details')),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('Participant Report'),
            onPressed: onOpenReport,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(email, style: Theme.of(context).textTheme.bodyMedium),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: $participantId',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _MetricCard(
                    label: context.tr('Joined Contests'),
                    value: stats.joinedContests.toString(),
                    color: AppColors.hotPink,
                    icon: Icons.emoji_events,
                  ),
                  _MetricCard(
                    label: context.tr('Approved'),
                    value: stats.approvedCount.toString(),
                    color: AppColors.neonGreen,
                    icon: Icons.check_circle,
                  ),
                  _MetricCard(
                    label: context.tr('Rejected'),
                    value: stats.rejectedCount.toString(),
                    color: Colors.redAccent,
                    icon: Icons.cancel,
                  ),
                  _MetricCard(
                    label: context.tr('Pending'),
                    value: stats.pendingCount.toString(),
                    color: AppColors.sunset,
                    icon: Icons.pending_actions,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Contest Activity'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (stats.contests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(context.tr('No contest activity found.')),
                )
              else
                ...stats.contests.map(
                  (row) => Container(
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
                        Text(
                          row.contestName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${context.tr('Status')}: ${context.tr(row.status)}',
                        ),
                        if (row.rejectionReason != '-')
                          Text(
                            '${context.tr('Reason')}: ${row.rejectionReason}',
                          ),
                        Text(
                          '${context.tr('Created At')}: ${row.createdAtText}',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({
    required this.title,
    required this.bytes,
    required this.filename,
  });

  final String title;
  final Uint8List bytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('Download'),
            onPressed: () =>
                Printing.sharePdf(bytes: bytes, filename: filename),
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: filename,
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

class _ParticipantMeta extends StatelessWidget {
  const _ParticipantMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
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
    return Expanded(
      child: Container(
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
                fontSize: 20,
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
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
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
              fontSize: 26,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
