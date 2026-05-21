import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class AdminContestDrawWinnersScreen extends StatefulWidget {
  const AdminContestDrawWinnersScreen({super.key});

  @override
  State<AdminContestDrawWinnersScreen> createState() =>
      _AdminContestDrawWinnersScreenState();
}

class _AdminContestDrawWinnersScreenState
    extends State<AdminContestDrawWinnersScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Contests')),
            Text(
              context.tr('Draw Winners'),
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
            stream: stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();
              final totalContests = docs.length;
              final completedDocs =
                  docs.where((doc) {
                    return doc.data()['drawCompleted'] == true;
                  }).toList()..sort((a, b) {
                    final aTime =
                        (a.data()['drawCompletedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    final bTime =
                        (b.data()['drawCompletedAt'] as Timestamp?)
                            ?.millisecondsSinceEpoch ??
                        0;
                    return bTime.compareTo(aTime);
                  });
              final readyDocs = docs.where(_isReadyToDraw).toList()
                ..sort((a, b) {
                  final aTime =
                      _bestContestDate(a.data())?.millisecondsSinceEpoch ?? 0;
                  final bTime =
                      _bestContestDate(b.data())?.millisecondsSinceEpoch ?? 0;
                  return bTime.compareTo(aTime);
                });
              final activeDocs = docs.where(_isActiveContest).toList();
              final totalWinners = completedDocs.fold<int>(
                0,
                (total, doc) =>
                    total +
                    (((doc.data()['drawWinnerCount'] ?? 0) as num).toInt()),
              );

              final visibleDocs = switch (_filter) {
                'ready' => readyDocs,
                'completed' => completedDocs,
                'active' => activeDocs,
                _ => [
                  ...readyDocs,
                  ...completedDocs.where((doc) => !readyDocs.contains(doc)),
                ],
              };

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width > 920
                          ? 4
                          : width > 620
                          ? 3
                          : 2;
                      final cards = [
                        _WinnerStatCard(
                          label: context.tr('Total Contests'),
                          value: '$totalContests',
                          icon: Icons.emoji_events_outlined,
                          color: const Color(0xFF9C62FF),
                        ),
                        _WinnerStatCard(
                          label: context.tr('Ready to Draw'),
                          value: '${readyDocs.length}',
                          icon: Icons.play_circle_outline_rounded,
                          color: const Color(0xFF38E27B),
                        ),
                        _WinnerStatCard(
                          label: context.tr('Completed Draws'),
                          value: '${completedDocs.length}',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF5AB4FF),
                        ),
                        _WinnerStatCard(
                          label: context.tr('Total Winners'),
                          value: '$totalWinners',
                          icon: Icons.workspace_premium_rounded,
                          color: AppColors.sunset,
                        ),
                      ];
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 118,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) => cards[index],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _WinnerChip(
                          label: context.tr('All'),
                          selected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _WinnerChip(
                          label: context.tr('Ready to Draw'),
                          selected: _filter == 'ready',
                          dotColor: const Color(0xFF38E27B),
                          onTap: () => setState(() => _filter = 'ready'),
                        ),
                        const SizedBox(width: 8),
                        _WinnerChip(
                          label: context.tr('Completed'),
                          selected: _filter == 'completed',
                          dotColor: const Color(0xFF5AB4FF),
                          onTap: () => setState(() => _filter = 'completed'),
                        ),
                        const SizedBox(width: 8),
                        _WinnerChip(
                          label: context.tr('Active'),
                          selected: _filter == 'active',
                          dotColor: AppColors.hotPink,
                          onTap: () => setState(() => _filter = 'active'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (visibleDocs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        context.tr('No contest draw winners yet.'),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    ...visibleDocs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final contest = entry.value;
                      final data = contest.data();
                      final title = (data['title'] ?? context.tr('Contest'))
                          .toString();
                      final subtitle =
                          (data['description'] ??
                                  data['prompt'] ??
                                  data['summary'] ??
                                  '')
                              .toString()
                              .trim();
                      final winnerCount =
                          ((data['drawWinnerCount'] ?? 0) as num).toInt();
                      final eligibleCount =
                          ((data['drawEligibleVoterCount'] ?? 0) as num)
                              .toInt();
                      final prizePool = ((data['winnerPrize'] ?? 0) as num)
                          .toDouble();
                      final participantCount =
                          ((data['participantCount'] ??
                                      data['submissionCount'] ??
                                      data['joinedCount'] ??
                                      0)
                                  as num)
                              .toInt();
                      final statusLabel = _contestCardStatus(context, data);
                      final statusColor = _contestCardStatusColor(data);
                      final startDate = _readDate(data, const [
                        'submissionStart',
                        'startDate',
                        'createdAt',
                      ]);
                      final endDate = _readDate(data, const [
                        'votingEnd',
                        'submissionEnd',
                        'endDate',
                      ]);

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: index == visibleDocs.length - 1 ? 0 : 12,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _AdminContestDrawWinnerDetailScreen(
                                      contestId: contest.id,
                                      title: title,
                                    ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF6330AA),
                                          Color(0xFF1B1730),
                                        ],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      title.isEmpty
                                          ? 'C'
                                          : title.characters.first
                                                .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
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
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
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
                                                color: statusColor.withValues(
                                                  alpha: 0.18,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
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
                                        if (subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 14,
                                          runSpacing: 8,
                                          children: [
                                            _WinnerMeta(
                                              icon:
                                                  Icons.calendar_today_outlined,
                                              label:
                                                  '${_fmtDate(startDate)} - ${_fmtDate(endDate)}',
                                            ),
                                            _WinnerMeta(
                                              icon: Icons.group_outlined,
                                              label:
                                                  '$participantCount ${context.tr('Videos')}',
                                            ),
                                            _WinnerMeta(
                                              icon: Icons.emoji_events_outlined,
                                              label:
                                                  '\$${prizePool.toStringAsFixed(prizePool % 1 == 0 ? 0 : 2)}',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _WinnerInfoBox(
                                      label: context.tr('Winners'),
                                      value: '$winnerCount',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _WinnerInfoBox(
                                      label: context.tr('Eligible'),
                                      value: '$eligibleCount',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _WinnerInfoBox(
                                      label: context.tr('Tap to open'),
                                      value: data['drawCompleted'] == true
                                          ? context.tr('View Winners')
                                          : context.tr('Preview Contest'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isReadyToDraw(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data['drawCompleted'] == true) return false;
    final now = DateTime.now();
    final votingEnd = _readDate(data, const ['votingEnd']);
    final submissionEnd = _readDate(data, const ['submissionEnd', 'endDate']);
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (votingEnd != null && !votingEnd.isAfter(now)) return true;
    if (submissionEnd != null && !submissionEnd.isAfter(now)) return true;
    return status == 'ended' || status == 'winner_announced';
  }

  bool _isActiveContest(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final status = (doc.data()['status'] ?? '').toString().toLowerCase();
    return status == 'active' || status == 'live';
  }

  String _contestCardStatus(BuildContext context, Map<String, dynamic> data) {
    if (data['drawCompleted'] == true) return context.tr('Completed');
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'active' || status == 'live') return context.tr('Active');
    if (_isReadyToDrawDoc(data)) return context.tr('Ready to Draw');
    return context.tr('Upcoming');
  }

  Color _contestCardStatusColor(Map<String, dynamic> data) {
    if (data['drawCompleted'] == true) return const Color(0xFF5AB4FF);
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'active' || status == 'live') return const Color(0xFF38E27B);
    if (_isReadyToDrawDoc(data)) return AppColors.sunset;
    return AppColors.hotPink;
  }

  bool _isReadyToDrawDoc(Map<String, dynamic> data) {
    if (data['drawCompleted'] == true) return false;
    final now = DateTime.now();
    final votingEnd = _readDate(data, const ['votingEnd']);
    final submissionEnd = _readDate(data, const ['submissionEnd', 'endDate']);
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (votingEnd != null && !votingEnd.isAfter(now)) return true;
    if (submissionEnd != null && !submissionEnd.isAfter(now)) return true;
    return status == 'ended' || status == 'winner_announced';
  }

  DateTime? _bestContestDate(Map<String, dynamic> data) {
    return _readDate(data, const [
      'drawCompletedAt',
      'votingEnd',
      'submissionEnd',
      'createdAt',
    ]);
  }

  DateTime? _readDate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  String _fmtDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';
  }

  String _month(int month) {
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
    return months[month - 1];
  }
}

class _AdminContestDrawWinnerDetailScreen extends StatelessWidget {
  const _AdminContestDrawWinnerDetailScreen({
    required this.contestId,
    required this.title,
  });

  final String contestId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final winnersStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('draw_winners')
        .orderBy('position')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            Text(
              context.tr('Lucky draw results'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('contests')
                .doc(contestId)
                .get(),
            builder: (context, contestSnap) {
              final contestData = contestSnap.data?.data() ?? const {};
              final winnerPrize = ((contestData['winnerPrize'] ?? 0) as num)
                  .toDouble();
              final winnerCount = ((contestData['drawWinnerCount'] ?? 0) as num)
                  .toInt();
              final eligibleCount =
                  ((contestData['drawEligibleVoterCount'] ?? 0) as num).toInt();
              final drawAt = (contestData['drawCompletedAt'] as Timestamp?)
                  ?.toDate();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: winnersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _WinnerInfoBox(
                              label: context.tr('Winners'),
                              value: '$winnerCount',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WinnerInfoBox(
                              label: context.tr('Eligible'),
                              value: '$eligibleCount',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _WinnerInfoBox(
                              label: context.tr('Prize Pool'),
                              value:
                                  '\$${winnerPrize.toStringAsFixed(winnerPrize % 1 == 0 ? 0 : 2)}',
                            ),
                          ),
                        ],
                      ),
                      if (drawAt != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: AppColors.hotPink,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${context.tr('Draw Completed At')}: ${_fmtDateTime(drawAt)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (docs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            context.tr('No contest draw winners yet.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      else
                        ...docs.asMap().entries.map((entry) {
                          final data = entry.value.data();
                          final position = ((data['position'] ?? 0) as num)
                              .toInt();
                          final userName =
                              (data['userName'] ?? context.tr('User'))
                                  .toString();
                          final userEmail = (data['userEmail'] ?? '')
                              .toString();
                          final userId = (data['userId'] ?? '').toString();
                          final prize = ((data['prizeAmount'] ?? 10) as num)
                              .toDouble();
                          final drawTime = (data['drawAt'] as Timestamp?)
                              ?.toDate();

                          return Container(
                            margin: EdgeInsets.only(
                              bottom: entry.key == docs.length - 1 ? 0 : 12,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.hotPink.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$position',
                                        style: const TextStyle(
                                          color: AppColors.hotPink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        userName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${prize.toStringAsFixed(prize % 1 == 0 ? 0 : 2)}',
                                      style: const TextStyle(
                                        color: AppColors.sunset,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 8,
                                  children: [
                                    _WinnerMeta(
                                      icon: Icons.person_outline_rounded,
                                      label:
                                          '${context.tr('User ID')}: $userId',
                                    ),
                                    if (userEmail.isNotEmpty)
                                      _WinnerMeta(
                                        icon: Icons.mail_outline_rounded,
                                        label: userEmail,
                                      ),
                                    if (drawTime != null)
                                      _WinnerMeta(
                                        icon: Icons.schedule_rounded,
                                        label: _fmtDateTime(drawTime),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
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

  String _fmtDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _month(int month) {
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
    return months[month - 1];
  }
}

class _WinnerStatCard extends StatelessWidget {
  const _WinnerStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerChip extends StatelessWidget {
  const _WinnerChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5E4C72) : const Color(0xFF18152A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerInfoBox extends StatelessWidget {
  const _WinnerInfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18152A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerMeta extends StatelessWidget {
  const _WinnerMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x44FF4FCB), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x2230E3CA), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
