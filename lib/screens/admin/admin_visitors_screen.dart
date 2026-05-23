import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
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
  final _authService = AuthService();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Visitors Management')),
            Text(
              context.tr('View and manage all visitors'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.68),
              ),
            ),
          ],
        ),
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

                    final filtered = docs.where((doc) {
                      final data = doc.data();
                      final isBlocked =
                          _effectiveAccountStatus(data) == 'disabled';
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

                    return FutureBuilder<_VisitorDashboardMetrics>(
                      future: _loadVisitorDashboardMetrics(docs),
                      builder: (context, metricsSnap) {
                        final metrics =
                            metricsSnap.data ??
                            _VisitorDashboardMetrics.empty(filtered.length);
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length + 1,
                          separatorBuilder: (_, index) => index == 0
                              ? const SizedBox(height: 14)
                              : const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final cardWidth = width >= 1100
                                      ? (width - 50) / 6
                                      : width >= 760
                                      ? (width - 30) / 3
                                      : (width - 10) / 2;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr('Total Visitors'),
                                          value: metrics.totalVisitors
                                              .toString(),
                                          hint: context.tr('All time'),
                                          color: AppColors.magenta,
                                          icon: Icons.people_alt_rounded,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr('Active Visitors'),
                                          value: metrics.activeVisitors
                                              .toString(),
                                          hint:
                                              '${metrics.activePercent.toStringAsFixed(1)}% ${context.tr('of total')}',
                                          color: AppColors.neonGreen,
                                          icon: Icons.verified_user_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr('Blocked Visitors'),
                                          value: metrics.blockedVisitors
                                              .toString(),
                                          hint:
                                              '${metrics.blockedPercent.toStringAsFixed(1)}% ${context.tr('of total')}',
                                          color: Colors.redAccent,
                                          icon: Icons.block_rounded,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr('Total Shares'),
                                          value: metrics.totalShares.toString(),
                                          hint: context.tr('All visitors'),
                                          color: AppColors.hotPink,
                                          icon: Icons.share_outlined,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr(
                                            'Total Video Views',
                                          ),
                                          value: metrics.totalViews.toString(),
                                          hint: context.tr('All visitors'),
                                          color: AppColors.sunset,
                                          icon: Icons.play_circle_outline,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _CountCard(
                                          label: context.tr('Total Votes'),
                                          value: metrics.totalVotes.toString(),
                                          hint: context.tr('All visitors'),
                                          color: AppColors.magenta,
                                          icon: Icons.how_to_vote_outlined,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }

                            final doc = filtered[index - 1];
                            final data = doc.data();
                            final name = (data['displayName'] ?? 'User')
                                .toString();
                            final email = (data['email'] ?? '').toString();
                            final phone = (data['phoneE164'] ?? '').toString();
                            final country =
                                (data['country'] ?? data['region'] ?? '-')
                                    .toString();
                            final isBlocked =
                                (data['accountStatus'] ?? 'active')
                                    .toString() ==
                                'disabled';
                            final lastActive = _formatLastActive(
                              data['updatedAt'] ?? data['createdAt'],
                            );
                            final shares =
                                metrics.perVisitorShares[doc.id] ?? 0;
                            final views = metrics.perVisitorViews[doc.id] ?? 0;
                            final votes = metrics.perVisitorVotes[doc.id] ?? 0;
                            final contests =
                                metrics.perVisitorContests[doc.id] ?? 0;
                            return _VisitorManagementCard(
                              name: name,
                              email: email,
                              phone: phone,
                              country: country,
                              isBlocked: isBlocked,
                              shares: shares,
                              views: views,
                              votes: votes,
                              contests: contests,
                              lastActive: lastActive,
                              onView: () =>
                                  _openDetails(visitorId: doc.id, data: data),
                              onReport: () => _openVisitorReport(
                                visitorId: doc.id,
                                data: data,
                              ),
                              onToggleBlock: () => _setVisitorStatus(
                                visitorId: doc.id,
                                status: isBlocked ? 'active' : 'disabled',
                              ),
                              onDelete: () => _confirmDeleteVisitor(
                                visitorId: doc.id,
                                name: name,
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

  Future<void> _setVisitorStatus({
    required String visitorId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(visitorId).set({
      'status': status,
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

  Future<void> _confirmDeleteVisitor({
    required String visitorId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(context.tr('Delete Visitor Permanently')),
        content: Text(
          context.tr(
            'Delete this visitor permanently? This removes the user from the app and authentication so the same email can register again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _authService.deleteUserAccountPermanently(visitorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Visitor deleted permanently.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Unable to delete this visitor right now.')),
        ),
      );
    }
  }

  Future<_VisitorDashboardMetrics> _loadVisitorDashboardMetrics(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final userIds = docs.map((doc) => doc.id).toSet().toList();
    final totalVisitors = docs.length;
    final blockedVisitors = docs
        .where((doc) => _effectiveAccountStatus(doc.data()) == 'disabled')
        .length;
    final activeVisitors = totalVisitors - blockedVisitors;

    final perVisitorShares = <String, int>{};
    final perVisitorViews = <String, int>{};
    for (final doc in docs) {
      final data = doc.data();
      perVisitorShares[doc.id] = ((data['shareCount'] ?? 0) as num).toInt();
      perVisitorViews[doc.id] =
          ((data['viewCount'] ?? data['views'] ?? 0) as num).toInt();
    }

    final votesSnap = await FirebaseFirestore.instance
        .collectionGroup('votes')
        .get();
    final perVisitorVotes = <String, int>{};
    final perVisitorContests = <String, Set<String>>{};
    for (final vote in votesSnap.docs) {
      final data = vote.data();
      final voterId = (data['voterId'] ?? vote.id).toString();
      if (!userIds.contains(voterId)) continue;
      perVisitorVotes[voterId] = (perVisitorVotes[voterId] ?? 0) + 1;
      final contestId = (data['contestId'] ?? '').toString();
      if (contestId.isNotEmpty) {
        perVisitorContests
            .putIfAbsent(voterId, () => <String>{})
            .add(contestId);
      }
    }

    return _VisitorDashboardMetrics(
      totalVisitors: totalVisitors,
      activeVisitors: activeVisitors,
      blockedVisitors: blockedVisitors,
      totalShares: perVisitorShares.values.fold(0, (a, b) => a + b),
      totalViews: perVisitorViews.values.fold(0, (a, b) => a + b),
      totalVotes: perVisitorVotes.values.fold(0, (a, b) => a + b),
      perVisitorShares: perVisitorShares,
      perVisitorViews: perVisitorViews,
      perVisitorVotes: perVisitorVotes,
      perVisitorContests: perVisitorContests.map(
        (key, value) => MapEntry(key, value.length),
      ),
    );
  }

  String _formatLastActive(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return '${dt.day.toString().padLeft(2, '0')} ${_monthShort(dt.month)} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  String _effectiveAccountStatus(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status.isNotEmpty) return status;
    return (data['accountStatus'] ?? 'active').toString().trim().toLowerCase();
  }

  String _monthShort(int month) {
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
    return months[(month - 1).clamp(0, 11)];
  }

  Future<void> _openAllVisitorsReport() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();
    final votesSnap = await FirebaseFirestore.instance
        .collectionGroup('votes')
        .get();

    final byVisitor =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
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
    final votesSnap = await FirebaseFirestore.instance
        .collectionGroup('votes')
        .get();
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
        participantName: submissionParticipantMap[submissionId] ?? submissionId,
        createdAtText: dateText(data['createdAt'] as Timestamp?),
      );
    }).toList()..sort((a, b) => b.createdAtText.compareTo(a.createdAtText));

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
    for (final doc in submissionsSnap.docs.where(
      (doc) => submissionIds.contains(doc.id),
    )) {
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

class _VisitorDashboardMetrics {
  const _VisitorDashboardMetrics({
    required this.totalVisitors,
    required this.activeVisitors,
    required this.blockedVisitors,
    required this.totalShares,
    required this.totalViews,
    required this.totalVotes,
    required this.perVisitorShares,
    required this.perVisitorViews,
    required this.perVisitorVotes,
    required this.perVisitorContests,
  });

  factory _VisitorDashboardMetrics.empty(int totalVisitors) =>
      _VisitorDashboardMetrics(
        totalVisitors: totalVisitors,
        activeVisitors: totalVisitors,
        blockedVisitors: 0,
        totalShares: 0,
        totalViews: 0,
        totalVotes: 0,
        perVisitorShares: const {},
        perVisitorViews: const {},
        perVisitorVotes: const {},
        perVisitorContests: const {},
      );

  final int totalVisitors;
  final int activeVisitors;
  final int blockedVisitors;
  final int totalShares;
  final int totalViews;
  final int totalVotes;
  final Map<String, int> perVisitorShares;
  final Map<String, int> perVisitorViews;
  final Map<String, int> perVisitorVotes;
  final Map<String, int> perVisitorContests;

  double get activePercent =>
      totalVisitors == 0 ? 0 : (activeVisitors / totalVisitors) * 100;
  double get blockedPercent =>
      totalVisitors == 0 ? 0 : (blockedVisitors / totalVisitors) * 100;
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
                    Text(
                      'ID: $visitorId',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CountCard(
                    label: context.tr('Total Contests Voted'),
                    value: stats.totalContestsVoted.toString(),
                    hint: context.tr('Voting history'),
                    color: AppColors.hotPink,
                    icon: Icons.how_to_vote_rounded,
                  ),
                  const SizedBox(width: 10),
                  _CountCard(
                    label: context.tr('Total Votes'),
                    value: stats.totalVotes.toString(),
                    hint: context.tr('All time'),
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
                        Text('${context.tr('Voted At')}: ${row.createdAtText}'),
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

class _VisitorManagementCard extends StatelessWidget {
  const _VisitorManagementCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.country,
    required this.isBlocked,
    required this.shares,
    required this.views,
    required this.votes,
    required this.contests,
    required this.lastActive,
    required this.onView,
    required this.onReport,
    required this.onToggleBlock,
    required this.onDelete,
  });

  final String name;
  final String email;
  final String phone;
  final String country;
  final bool isBlocked;
  final int shares;
  final int views;
  final int votes;
  final int contests;
  final String lastActive;
  final VoidCallback onView;
  final VoidCallback onReport;
  final VoidCallback onToggleBlock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = isBlocked ? Colors.redAccent : AppColors.neonGreen;
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isBlocked
                    ? Colors.redAccent.withOpacity(0.18)
                    : AppColors.magenta.withOpacity(0.20),
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            context.tr(isBlocked ? 'Blocked' : 'Active'),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email, style: Theme.of(context).textTheme.bodySmall),
                    if (phone.isNotEmpty)
                      Text(phone, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _VisitorInlineInfo(
                icon: Icons.public,
                label: context.tr('Country'),
                value: country,
              ),
              _VisitorInlineInfo(
                icon: Icons.share_outlined,
                label: context.tr('Shares'),
                value: shares.toString(),
              ),
              _VisitorInlineInfo(
                icon: Icons.visibility_outlined,
                label: context.tr('Views'),
                value: views.toString(),
              ),
              _VisitorInlineInfo(
                icon: Icons.how_to_vote_outlined,
                label: context.tr('Votes'),
                value: votes.toString(),
              ),
              _VisitorInlineInfo(
                icon: Icons.emoji_events_outlined,
                label: context.tr('Contests'),
                value: contests.toString(),
              ),
              _VisitorInlineInfo(
                icon: Icons.schedule_outlined,
                label: context.tr('Last Active'),
                value: lastActive,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _VisitorActionButton(
                  onPressed: onView,
                  icon: Icons.visibility_outlined,
                  label: context.tr('Details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VisitorActionButton(
                  onPressed: onReport,
                  icon: Icons.picture_as_pdf,
                  label: context.tr('Report'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VisitorActionButton(
                  onPressed: onToggleBlock,
                  icon: isBlocked
                      ? Icons.lock_open_rounded
                      : Icons.block_rounded,
                  label: context.tr(isBlocked ? 'Unblock' : 'Block'),
                  filled: true,
                  backgroundColor: isBlocked
                      ? AppColors.neonGreen
                      : Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                child: _VisitorActionButton(
                  onPressed: onDelete,
                  icon: Icons.delete_forever_rounded,
                  label: '',
                  filled: true,
                  backgroundColor: const Color(0xFF902B36),
                  foregroundColor: Colors.white,
                  iconOnly: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitorActionButton extends StatelessWidget {
  const _VisitorActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.iconOnly = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool filled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final child = iconOnly
        ? Icon(icon, size: 20)
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    if (filled) {
      return SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        child: child,
      ),
    );
  }
}

class _VisitorInlineInfo extends StatelessWidget {
  const _VisitorInlineInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.hotPink),
          const SizedBox(width: 8),
          Flexible(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String hint;
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final first = parts.first;
    return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
