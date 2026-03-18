import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/l10n.dart';
import '../../services/visitor_report_service.dart';
import '../../theme/app_colors.dart';

class AdminVisitorsScreen extends StatefulWidget {
  const AdminVisitorsScreen({super.key});

  @override
  State<AdminVisitorsScreen> createState() => _AdminVisitorsScreenState();
}

class _AdminVisitorsScreenState extends State<AdminVisitorsScreen> {
  final _searchController = TextEditingController();
  final _reportService = VisitorReportService();
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
        .where('role', isEqualTo: 'user')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Visitors')),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('All Visitors Report'),
            onPressed: _openAllVisitorsReport,
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
                            'Search visitor by name or email',
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

                    final totalVisitors = docs.length;
                    final blockedVisitors = docs
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

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(context.tr('No matching visitors.')),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              _CountCard(
                                label: context.tr('Total Visitors'),
                                value: totalVisitors.toString(),
                                color: AppColors.magenta,
                                icon: Icons.visibility,
                              ),
                              const SizedBox(width: 10),
                              _CountCard(
                                label: context.tr('Visible'),
                                value: filtered.length.toString(),
                                color: AppColors.hotPink,
                                icon: Icons.remove_red_eye_outlined,
                              ),
                              const SizedBox(width: 10),
                              _CountCard(
                                label: context.tr('Blocked'),
                                value: blockedVisitors.toString(),
                                color: Colors.redAccent,
                                icon: Icons.block,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data = doc.data();
                              final name =
                                  (data['displayName'] ?? 'User').toString();
                              final email = (data['email'] ?? '').toString();
                              final phone = (data['phoneE164'] ?? '').toString();
                              final isBlocked =
                                  (data['accountStatus'] ?? 'active')
                                      .toString() ==
                                  'disabled';
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? Colors.redAccent.withOpacity(0.18)
                                            : AppColors.magenta.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        isBlocked
                                            ? Icons.block
                                            : Icons.visibility,
                                        color: isBlocked
                                            ? Colors.redAccent
                                            : AppColors.magenta,
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
                                                  BorderRadius.circular(999),
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
                                                fontWeight: FontWeight.w700,
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
                                        visitorId: doc.id,
                                        data: data,
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        color: AppColors.hotPink,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: context.tr('Visitor Report'),
                                      onPressed: () => _openVisitorReport(
                                        visitorId: doc.id,
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
                                          await _setVisitorStatus(
                                            visitorId: doc.id,
                                            status: 'disabled',
                                          );
                                        } else if (value == 'unblock') {
                                          await _setVisitorStatus(
                                            visitorId: doc.id,
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
                                                  ? 'Unblock Visitor'
                                                  : 'Block Visitor',
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

  Future<void> _setVisitorStatus({
    required String visitorId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(visitorId).set({
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
                ? 'Visitor access blocked.'
                : 'Visitor access restored.',
          ),
        ),
      ),
    );
  }

  Future<void> _openAllVisitorsReport() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();
    final votesSnap = await FirebaseFirestore.instance.collectionGroup('votes').get();

    final byVisitor = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in votesSnap.docs) {
      final voterId = (doc.data()['voterId'] ?? doc.id).toString();
      if (voterId.isEmpty) continue;
      byVisitor.putIfAbsent(voterId, () => []).add(doc);
    }

    final rows = usersSnap.docs.map((doc) {
      final data = doc.data();
      final votes = byVisitor[doc.id] ?? const [];
      final contests = votes
          .map((e) => (e.data()['contestId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;
      return VisitorSummaryRow(
        name: (data['displayName'] ?? '').toString(),
        email: (data['email'] ?? '').toString(),
        phone: (data['phoneE164'] ?? '').toString(),
        totalContestsVoted: contests,
        totalVotes: votes.length,
      );
    }).toList();

    final bytes = await _reportService.buildAllVisitorsReport(rows: rows);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('All Visitors Report'),
          bytes: bytes,
          filename: 'all-visitors-report.pdf',
        ),
      ),
    );
  }

  Future<void> _openDetails({
    required String visitorId,
    required Map<String, dynamic> data,
  }) async {
    final stats = await _loadVisitorStats(visitorId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisitorDetailScreen(
          visitorId: visitorId,
          data: data,
          stats: stats,
          onOpenReport: () =>
              _openVisitorReport(visitorId: visitorId, data: data),
        ),
      ),
    );
  }

  Future<void> _openVisitorReport({
    required String visitorId,
    required Map<String, dynamic> data,
  }) async {
    final stats = await _loadVisitorStats(visitorId);
    final bytes = await _reportService.buildSingleVisitorReport(
      visitorName: (data['displayName'] ?? '').toString(),
      visitorEmail: (data['email'] ?? '').toString(),
      visitorPhone: (data['phoneE164'] ?? '').toString(),
      totalContestsVoted: stats.totalContestsVoted,
      totalVotes: stats.totalVotes,
      votes: stats.votes,
    );
    if (!mounted) return;
    final safeName = (data['displayName'] ?? 'visitor')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('Visitor Report'),
          bytes: bytes,
          filename: '$safeName-visitor-report.pdf',
        ),
      ),
    );
  }

  Future<_VisitorStats> _loadVisitorStats(String visitorId) async {
    final votesSnap = await FirebaseFirestore.instance.collectionGroup('votes').get();
    final visitorVotes = votesSnap.docs.where((doc) {
      final data = doc.data();
      final voterId = (data['voterId'] ?? doc.id).toString();
      return voterId == visitorId;
    }).toList();

    final contestIds = visitorVotes
        .map((doc) => (doc.data()['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final submissionIds = visitorVotes
        .map((doc) => (doc.data()['submissionId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final contestMap = await _loadContestMap(contestIds);
    final submissionParticipantMap = await _loadSubmissionParticipantMap(
      submissionIds,
    );

    String dateText(Timestamp? ts) {
      if (ts == null) return '-';
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final voteRows = visitorVotes.map((doc) {
      final data = doc.data();
      final contestId = (data['contestId'] ?? '').toString();
      final submissionId = (data['submissionId'] ?? '').toString();
      return VisitorVoteRow(
        contestName: contestMap[contestId] ?? contestId,
        participantName:
            submissionParticipantMap[submissionId] ?? submissionId,
        createdAtText: dateText(data['createdAt'] as Timestamp?),
      );
    }).toList()
      ..sort((a, b) => b.createdAtText.compareTo(a.createdAtText));

    return _VisitorStats(
      totalContestsVoted: contestIds.length,
      totalVotes: visitorVotes.length,
      votes: voteRows,
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

  Future<Map<String, String>> _loadSubmissionParticipantMap(
    List<String> submissionIds,
  ) async {
    if (submissionIds.isEmpty) return <String, String>{};
    final submissionsSnap = await FirebaseFirestore.instance
        .collectionGroup('submissions')
        .get();
    final userIds = submissionsSnap.docs
        .where((doc) => submissionIds.contains(doc.id))
        .map((doc) => (doc.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final userMap = <String, String>{};
    for (var i = 0; i < userIds.length; i += 10) {
      final chunk = userIds.sublist(
        i,
        i + 10 > userIds.length ? userIds.length : i + 10,
      );
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        userMap[doc.id] = (doc.data()['displayName'] ?? doc.id).toString();
      }
    }
    final result = <String, String>{};
    for (final doc in submissionsSnap.docs.where((doc) => submissionIds.contains(doc.id))) {
      final userId = (doc.data()['userId'] ?? '').toString();
      result[doc.id] = userMap[userId] ?? userId;
    }
    return result;
  }
}

class _VisitorStats {
  const _VisitorStats({
    required this.totalContestsVoted,
    required this.totalVotes,
    required this.votes,
  });

  final int totalContestsVoted;
  final int totalVotes;
  final List<VisitorVoteRow> votes;
}

class _VisitorDetailScreen extends StatelessWidget {
  const _VisitorDetailScreen({
    required this.visitorId,
    required this.data,
    required this.stats,
    required this.onOpenReport,
  });

  final String visitorId;
  final Map<String, dynamic> data;
  final _VisitorStats stats;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final name = (data['displayName'] ?? 'User').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phoneE164'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Visitor Details')),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('Visitor Report'),
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
                    Text('ID: $visitorId',
                        style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CountCard(
                    label: context.tr('Total Contests Voted'),
                    value: stats.totalContestsVoted.toString(),
                    color: AppColors.hotPink,
                    icon: Icons.how_to_vote_rounded,
                  ),
                  const SizedBox(width: 10),
                  _CountCard(
                    label: context.tr('Total Votes'),
                    value: stats.totalVotes.toString(),
                    color: AppColors.magenta,
                    icon: Icons.favorite_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Voting Activity'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (stats.votes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(context.tr('No voting activity found.')),
                )
              else
                ...stats.votes.map(
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
                          '${context.tr('Participant')}: ${row.participantName}',
                        ),
                        Text(
                          '${context.tr('Voted At')}: ${row.createdAtText}',
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
