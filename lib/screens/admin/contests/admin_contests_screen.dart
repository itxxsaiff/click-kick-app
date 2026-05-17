import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/contest_report_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pdf_preview_screen.dart';
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
  String _statusFilter = 'all';
  String _countryFilter = 'all';
  String _categoryFilter = 'all';
  String _dateFilter = 'all';
  bool _listMode = true;

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

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  int _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
    }
    return 0;
  }

  double _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  String _contestLifecycle(Map<String, dynamic> data, DateTime now) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    final votingStart = _readDate(data['votingStart']);
    final votingEnd =
        _readDate(data['votingEnd']) ??
        _readDate(data['submissionEnd']) ??
        _readDate(data['endDate']);
    if (status == 'cancelled' || status == 'rejected') return 'ended';
    if (votingEnd != null && !votingEnd.isAfter(now)) return 'ended';
    if (votingStart != null && votingStart.isAfter(now)) return 'upcoming';
    return 'active';
  }

  int? _daysUntilVotingStart(Map<String, dynamic> data, DateTime now) {
    final votingStart = _readDate(data['votingStart']);
    if (votingStart == null || !votingStart.isAfter(now)) return null;
    final diff = votingStart.difference(now);
    return diff.inHours <= 24
        ? 1
        : diff.inDays + (diff.inHours % 24 == 0 ? 0 : 1);
  }

  bool _matchesDateFilter(Map<String, dynamic> data, DateTime now) {
    if (_dateFilter == 'all') return true;
    final createdAt =
        _readDate(data['createdAt']) ??
        _readDate(data['submissionStart']) ??
        _readDate(data['votingStart']) ??
        _readDate(data['submissionEnd']) ??
        _readDate(data['votingEnd']);
    if (createdAt == null) return _dateFilter == 'all';
    switch (_dateFilter) {
      case 'month':
        return createdAt.year == now.year && createdAt.month == now.month;
      case 'quarter':
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final createdQuarter = ((createdAt.month - 1) ~/ 3) + 1;
        return createdAt.year == now.year && createdQuarter == currentQuarter;
      case 'year':
        return createdAt.year == now.year;
      default:
        return true;
    }
  }

  String _compactNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Contests (Admin)')),
            Text(
              context.tr('Manage contests'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
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
              label: Text(context.tr('Add Contest')),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: contests,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final docs =
                  snapshot.data!.docs.where((doc) {
                    final rawType =
                        (doc.data()['contestType'] ?? 'video_contest')
                            .toString();
                    return rawType != 'sponsor_contest';
                  }).toList()..sort((a, b) {
                    final at =
                        _readDate(
                          a.data()['createdAt'],
                        )?.millisecondsSinceEpoch ??
                        0;
                    final bt =
                        _readDate(
                          b.data()['createdAt'],
                        )?.millisecondsSinceEpoch ??
                        0;
                    return _sortDesc ? bt.compareTo(at) : at.compareTo(bt);
                  });

              final countryOptions = <String>{
                'all',
                ...docs
                    .map(
                      (doc) => (doc.data()['region'] ?? '').toString().trim(),
                    )
                    .where((value) => value.isNotEmpty),
              }.toList();
              final categoryOptions = <String>{
                'all',
                ...docs
                    .map(
                      (doc) => (doc.data()['category'] ?? '').toString().trim(),
                    )
                    .where((value) => value.isNotEmpty),
              }.toList();

              if (!countryOptions.contains(_countryFilter)) {
                _countryFilter = 'all';
              }
              if (!categoryOptions.contains(_categoryFilter)) {
                _categoryFilter = 'all';
              }

              final filtered = docs.where((doc) {
                final data = doc.data();
                final lifecycle = _contestLifecycle(data, now);
                final region = (data['region'] ?? '').toString().trim();
                final category = (data['category'] ?? '').toString().trim();
                final haystack = [
                  data['title'],
                  data['description'],
                  data['region'],
                  data['category'],
                ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

                if (_search.isNotEmpty && !haystack.contains(_search)) {
                  return false;
                }
                if (_statusFilter != 'all' && lifecycle != _statusFilter) {
                  return false;
                }
                if (_countryFilter != 'all' && region != _countryFilter) {
                  return false;
                }
                if (_categoryFilter != 'all' && category != _categoryFilter) {
                  return false;
                }
                if (!_matchesDateFilter(data, now)) {
                  return false;
                }
                return true;
              }).toList();

              int totalParticipants = 0;
              int totalVotes = 0;
              int activeCount = 0;
              int upcomingCount = 0;
              int endedCount = 0;

              for (final doc in docs) {
                final data = doc.data();
                totalParticipants += _readInt(data, const [
                  'participantsCount',
                  'participantCount',
                  'totalParticipants',
                  'submissionCount',
                  'joinedCount',
                ]);
                totalVotes += _readInt(data, const [
                  'voteCount',
                  'votesCount',
                  'totalVotes',
                ]);
                switch (_contestLifecycle(data, now)) {
                  case 'active':
                    activeCount++;
                    break;
                  case 'upcoming':
                    upcomingCount++;
                    break;
                  case 'ended':
                    endedCount++;
                    break;
                }
              }

              final activeFilterCount =
                  (_statusFilter == 'all' ? 0 : 1) +
                  (_countryFilter == 'all' ? 0 : 1) +
                  (_categoryFilter == 'all' ? 0 : 1) +
                  (_dateFilter == 'all' ? 0 : 1);
              final screenWidth = MediaQuery.of(context).size.width;
              final statGridColumns = screenWidth >= 1200
                  ? 6
                  : screenWidth >= 960
                  ? 4
                  : screenWidth >= 700
                  ? 3
                  : 2;
              final filterColumns = screenWidth >= 1100
                  ? 4
                  : screenWidth >= 760
                  ? 2
                  : 1;
              final filterWidth =
                  (screenWidth - 32 - ((filterColumns - 1) * 10)) /
                  filterColumns;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  GridView.count(
                    crossAxisCount: statGridColumns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: screenWidth >= 960
                        ? 1.18
                        : screenWidth >= 700
                        ? 1.05
                        : 0.98,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _ContestStatCard(
                        icon: Icons.emoji_events_outlined,
                        iconColor: const Color(0xFFB166FF),
                        label: context.tr('Total Contests'),
                        value: docs.length.toString(),
                        accent: const Color(0xFF8A54F7),
                        note: context.tr('All contests'),
                      ),
                      _ContestStatCard(
                        icon: Icons.play_circle_fill_rounded,
                        iconColor: const Color(0xFF3DE070),
                        label: context.tr('Active'),
                        value: activeCount.toString(),
                        accent: const Color(0xFF1FB85D),
                        note: context.tr('Live now'),
                      ),
                      _ContestStatCard(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFFF3A329),
                        label: context.tr('Upcoming'),
                        value: upcomingCount.toString(),
                        accent: const Color(0xFFE48612),
                        note: context.tr('Voting not started'),
                      ),
                      _ContestStatCard(
                        icon: Icons.stop_circle_outlined,
                        iconColor: const Color(0xFFFF647A),
                        label: context.tr('Ended'),
                        value: endedCount.toString(),
                        accent: const Color(0xFFC53F57),
                        note: context.tr('Finished contests'),
                      ),
                      _ContestStatCard(
                        icon: Icons.groups_2_outlined,
                        iconColor: const Color(0xFF64A8FF),
                        label: context.tr('Total Participants'),
                        value: _compactNumber(totalParticipants),
                        accent: const Color(0xFF3A7EFF),
                        note: context.tr('Joined users'),
                      ),
                      _ContestStatCard(
                        icon: Icons.how_to_vote_rounded,
                        iconColor: const Color(0xFFFFD761),
                        label: context.tr('Total Votes'),
                        value: _compactNumber(totalVotes),
                        accent: const Color(0xFFC9A130),
                        note: context.tr('All votes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18152A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border.withOpacity(0.85),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(
                              () => _search = value.trim().toLowerCase(),
                            ),
                            decoration: InputDecoration(
                              hintText: context.tr(
                                'Search contests by name, country, category...',
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 6, right: 8),
                                child: Icon(Icons.search),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _search = '');
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18152A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.85),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.filter_alt_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('Filters'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (activeFilterCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF8A54F7),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: filterWidth,
                        child: _FilterSelect(
                          label: context.tr('Status'),
                          value: _statusFilter,
                          options: const ['all', 'active', 'upcoming', 'ended'],
                          valueLabel: (value) => switch (value) {
                            'active' => context.tr('Active'),
                            'upcoming' => context.tr('Upcoming'),
                            'ended' => context.tr('Ended'),
                            _ => context.tr('All'),
                          },
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        child: _FilterSelect(
                          label: context.tr('Country'),
                          value: _countryFilter,
                          options: countryOptions,
                          valueLabel: (value) =>
                              value == 'all' ? context.tr('All') : value,
                          onChanged: (value) =>
                              setState(() => _countryFilter = value),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        child: _FilterSelect(
                          label: context.tr('Category'),
                          value: _categoryFilter,
                          options: categoryOptions,
                          valueLabel: (value) =>
                              value == 'all' ? context.tr('All') : value,
                          onChanged: (value) =>
                              setState(() => _categoryFilter = value),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        child: _FilterSelect(
                          label: context.tr('Date'),
                          value: _dateFilter,
                          options: const ['all', 'month', 'quarter', 'year'],
                          valueLabel: (value) => switch (value) {
                            'month' => context.tr('This Month'),
                            'quarter' => context.tr('This Quarter'),
                            'year' => context.tr('This Year'),
                            _ => context.tr('All Time'),
                          },
                          onChanged: (value) =>
                              setState(() => _dateFilter = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        onSelected: (_) => setState(() => _sortDesc = false),
                      ),
                      const Spacer(),
                      _ViewModeButton(
                        selected: _listMode,
                        icon: Icons.view_list_rounded,
                        onTap: () => setState(() => _listMode = true),
                      ),
                      const SizedBox(width: 8),
                      _ViewModeButton(
                        selected: !_listMode,
                        icon: Icons.grid_view_rounded,
                        onTap: () => setState(() => _listMode = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          context.tr('No matching contests.'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((doc) {
                      final data = doc.data();
                      final title = (data['title'] ?? '').toString();
                      final desc = (data['description'] ?? '').toString();
                      final logoUrl = (data['logoUrl'] ?? '').toString();
                      final country = (data['region'] ?? '').toString().trim();
                      final category =
                          (data['category'] ?? context.tr('General'))
                              .toString()
                              .trim();
                      final startDate =
                          _readDate(data['submissionStart']) ??
                          _readDate(data['startDate']);
                      final endDate =
                          _readDate(data['submissionEnd']) ??
                          _readDate(data['endDate']) ??
                          _readDate(data['votingEnd']);
                      final winnerPrize = _readDouble(data, const [
                        'winnerPrize',
                        'prize',
                      ]);
                      final participants = _readInt(data, const [
                        'participantsCount',
                        'participantCount',
                        'totalParticipants',
                        'submissionCount',
                        'joinedCount',
                      ]);
                      final votes = _readInt(data, const [
                        'voteCount',
                        'votesCount',
                        'totalVotes',
                      ]);
                      final lifecycle = _contestLifecycle(data, now);
                      final daysLeft = _daysUntilVotingStart(data, now);
                      final statusColor = _statusColor(lifecycle);
                      final statusLabel = _statusLabel(context, lifecycle);
                      final isCompactCard = screenWidth < 900;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18152A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.92),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 98,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: logoUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.network(
                                            logoUrl,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF57238E),
                                                Color(0xFF1E1537),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Text(
                                                title.toUpperCase(),
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
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
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.16,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        desc.isEmpty
                                            ? context.tr(
                                                'Video contest submission',
                                              )
                                            : desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
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
                                            context.tr(
                                              'This cannot be undone.',
                                            ),
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
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: AppColors.border.withOpacity(0.6),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.event_outlined,
                                    label: context.tr('Start Date'),
                                    value: _formatShortDate(startDate),
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.event_available_outlined,
                                    label: context.tr('End Date'),
                                    value: _formatShortDate(endDate),
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.groups_2_outlined,
                                    label: context.tr('Participants'),
                                    value: participants.toString(),
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.emoji_events_outlined,
                                    label: context.tr('Prize'),
                                    value:
                                        '\$${winnerPrize.toStringAsFixed(winnerPrize % 1 == 0 ? 0 : 2)}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.public_outlined,
                                    label: context.tr('Country'),
                                    value: country.isEmpty
                                        ? context.tr('Not set')
                                        : country,
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.folder_open_outlined,
                                    label: context.tr('Category'),
                                    value: category,
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : (screenWidth - 216) / 4,
                                  child: _ContestInfoCell(
                                    icon: Icons.how_to_vote_outlined,
                                    label: context.tr('Votes'),
                                    value: _compactNumber(votes),
                                  ),
                                ),
                                SizedBox(
                                  width: isCompactCard
                                      ? (screenWidth - 88) / 2
                                      : 96,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF12101D),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.border.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          lifecycle == 'ended'
                                              ? context.tr('Ended')
                                              : lifecycle == 'active'
                                              ? context.tr('Live')
                                              : '${daysLeft ?? 0}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: lifecycle == 'ended'
                                                ? AppColors.textMuted
                                                : lifecycle == 'active'
                                                ? const Color(0xFF39DF79)
                                                : const Color(0xFFFFD761),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lifecycle == 'ended'
                                              ? context.tr('Finished')
                                              : lifecycle == 'active'
                                              ? context.tr('Voting Live')
                                              : context.tr('Days Left'),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                    }),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      context.tr('No more contests'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
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

class _ContestStatCard extends StatelessWidget {
  const _ContestStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.accent,
    required this.note,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color accent;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171425),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String Function(String value) valueLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF18152A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.85)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF18152A),
          borderRadius: BorderRadius.circular(16),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        valueLabel(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B3FF2) : const Color(0xFF18152A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.8)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ContestInfoCell extends StatelessWidget {
  const _ContestInfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
