import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/contest_report_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pdf_preview_screen.dart';
import 'admin_contest_form.dart';
import 'admin_video_contest_form.dart';

class AdminContestsScreen extends StatefulWidget {
  const AdminContestsScreen({super.key});

  @override
  State<AdminContestsScreen> createState() => _AdminContestsScreenState();
}

class _AdminContestsScreenState extends State<AdminContestsScreen> {
  final _searchController = TextEditingController();
  final _reportService = ContestReportService();

  String _search = '';
  bool _sortDesc = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
      case 'active':
        return const Color(0xFF39DF79);
      case 'contest_created':
      case 'upcoming':
        return const Color(0xFF429CFF);
      case 'draft':
        return const Color(0xFFA67BFF);
      case 'ended':
      case 'completed':
        return const Color(0xFF9AA2B5);
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFFF647A);
      default:
        return AppColors.sunset;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return context.tr('Active');
      case 'contest_created':
        return context.tr('Upcoming');
      case 'draft':
        return context.tr('Draft');
      case 'ended':
        return context.tr('Ended');
      case 'cancelled':
        return context.tr('Cancelled');
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return 'Not set';
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
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openContestReport({
    required String contestId,
    required Map<String, dynamic> data,
  }) async {
    final title = (data['title'] ?? contestId).toString();
    final bytes = await _reportService.buildContestReportFromFirestore(
      contestId: contestId,
      contestData: data,
    );
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final contests = FirebaseFirestore.instance
        .collection('contests')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Contests')),
        backgroundColor: AppColors.deepSpace,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminVideoContestForm(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('Add')),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18152A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.85),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: context.tr('Search contests'),
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
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
                      onSelected: (_) => setState(() => _sortDesc = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: contests,
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
                      final rawType = (data['contestType'] ?? 'video_contest')
                          .toString();
                      if (rawType == 'sponsor_contest') return false;
                      if (_search.isEmpty) return true;
                      final haystack =
                          [data['title'], data['description'], data['region']]
                              .map((e) => (e ?? '').toString().toLowerCase())
                              .join(' ');
                      return haystack.contains(_search);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          context.tr('No matching contests.'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: Center(
                              child: Text(
                                context.tr('No more contests'),
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
                        final title = (data['title'] ?? '').toString();
                        final desc = (data['description'] ?? '').toString();
                        final logoUrl = (data['logoUrl'] ?? '').toString();
                        final statusRaw = (data['status'] ?? 'contest_created')
                            .toString();
                        final status = _statusLabel(context, statusRaw);
                        final statusColor = _statusColor(statusRaw);
                        final participants =
                            (data['participantsCount'] ??
                                    data['participantCount'] ??
                                    data['totalParticipants'] ??
                                    0)
                                .toString();
                        final endDate =
                            (data['submissionEnd'] as Timestamp?)?.toDate() ??
                            (data['endDate'] as Timestamp?)?.toDate() ??
                            (data['votingEnd'] as Timestamp?)?.toDate();
                        final dateLabel = endDate == null
                            ? context.tr('Date')
                            : context.tr('End Date');

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18152A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.9),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 92,
                                height: 72,
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
                                    : Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF4E1C7E),
                                              Color(0xFF21113B),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Text(
                                              title.toUpperCase(),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                height: 1.05,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.groups_2_outlined,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          participants,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.tr('Participants'),
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formatShortDate(endDate),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (desc.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdminVideoContestForm(
                                          contestId: doc.id,
                                          existing: data,
                                        ),
                                      ),
                                    );
                                  } else if (value == 'report') {
                                    await _openContestReport(
                                      contestId: doc.id,
                                      data: data,
                                    );
                                  } else if (value == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          context.tr('Delete contest?'),
                                        ),
                                        content: Text(
                                          context.tr('This cannot be undone.'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(context.tr('Cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(context.tr('Delete')),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await doc.reference.delete();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Text(context.tr('Contest Report')),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.tr('Edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.tr('Delete')),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
