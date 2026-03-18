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
  bool _sortDesc = true;
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'participant')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Participants')),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('All Participants Report'),
            onPressed: _openAllParticipantsReport,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
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
                          hintText: context.tr(
                            'Search participant by name or email',
                          ),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(context.tr('Newest First')),
                            selected: _sortDesc,
                            onSelected: (_) => setState(() => _sortDesc = true),
                          ),
                          ChoiceChip(
                            label: Text(context.tr('Oldest First')),
                            selected: !_sortDesc,
                            onSelected: (_) =>
                                setState(() => _sortDesc = false),
                          ),
                          FilterChip(
                            label: Text(context.tr('All')),
                            selected: _filter == 'all',
                            onSelected: (_) => setState(() => _filter = 'all'),
                          ),
                          FilterChip(
                            label: Text(context.tr('Active')),
                            selected: _filter == 'active',
                            onSelected: (_) =>
                                setState(() => _filter = 'active'),
                          ),
                          FilterChip(
                            label: Text(context.tr('Blocked')),
                            selected: _filter == 'blocked',
                            onSelected: (_) =>
                                setState(() => _filter = 'blocked'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final at =
                            (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final bt =
                            (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return _sortDesc ? bt.compareTo(at) : at.compareTo(bt);
                      });

                    final totalParticipants = docs.length;
                    final blockedParticipants = docs
                        .where(
                          (doc) =>
                              (doc.data()['accountStatus'] ?? 'active')
                                  .toString() ==
                              'disabled',
                        )
                        .length;

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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              _CountCard(
                                label: context.tr('Total Participants'),
                                value: totalParticipants.toString(),
                                color: AppColors.neonGreen,
                                icon: Icons.groups,
                              ),
                              const SizedBox(width: 10),
                              _CountCard(
                                label: context.tr('Visible'),
                                value: filtered.length.toString(),
                                color: AppColors.hotPink,
                                icon: Icons.visibility,
                              ),
                              const SizedBox(width: 10),
                              _CountCard(
                                label: context.tr('Blocked'),
                                value: blockedParticipants.toString(),
                                color: Colors.redAccent,
                                icon: Icons.block,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    context.tr('No matching participants.'),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final doc = filtered[index];
                                    final data = doc.data();
                                    final name = (data['displayName'] ?? 'User')
                                        .toString();
                                    final email = (data['email'] ?? '')
                                        .toString();
                                    final phone = (data['phoneE164'] ?? '')
                                        .toString();
                                    final isBlocked =
                                        (data['accountStatus'] ?? 'active')
                                            .toString() ==
                                        'disabled';
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: isBlocked
                                                  ? Colors.redAccent
                                                        .withOpacity(0.18)
                                                  : AppColors.neonGreen
                                                        .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              isBlocked
                                                  ? Icons.block
                                                  : Icons.person,
                                              color: isBlocked
                                                  ? Colors.redAccent
                                                  : AppColors.neonGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  email,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                                if (phone.isNotEmpty)
                                                  Text(
                                                    phone,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isBlocked
                                                        ? Colors.redAccent
                                                              .withOpacity(0.18)
                                                        : AppColors.neonGreen
                                                              .withOpacity(0.18),
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
                                                      color: isBlocked
                                                          ? Colors.redAccent
                                                          : AppColors.neonGreen,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: context.tr('View Details'),
                                            onPressed: () => _openDetails(
                                              participantId: doc.id,
                                              data: data,
                                            ),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              color: AppColors.hotPink,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: context.tr(
                                              'Participant Report',
                                            ),
                                            onPressed: () =>
                                                _openParticipantReport(
                                                  participantId: doc.id,
                                                  data: data,
                                                ),
                                            icon: const Icon(
                                              Icons.picture_as_pdf,
                                              color: AppColors.sunset,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'block') {
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setParticipantStatus({
    required String participantId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(participantId).set({
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

    final byParticipant = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
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
          .where((e) => (e.data()['status'] ?? 'pending').toString() == 'pending')
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
    }).toList()
      ..sort((a, b) => b.createdAtText.compareTo(a.createdAtText));

    return _ParticipantStats(
      joinedContests: contestIds.length,
      approvedCount: submissions
          .where((doc) => (doc.data()['status'] ?? '').toString() == 'approved')
          .length,
      rejectedCount: submissions
          .where((doc) => (doc.data()['status'] ?? '').toString() == 'rejected')
          .length,
      pendingCount: submissions
          .where((doc) => (doc.data()['status'] ?? 'pending').toString() == 'pending')
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
                    Text('ID: $participantId',
                        style: const TextStyle(color: AppColors.textMuted)),
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
                        Text('${context.tr('Status')}: ${context.tr(row.status)}'),
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
            onPressed: () => Printing.sharePdf(bytes: bytes, filename: filename),
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
