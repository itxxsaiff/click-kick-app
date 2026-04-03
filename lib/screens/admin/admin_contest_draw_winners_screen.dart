import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';

class AdminContestDrawWinnersScreen extends StatelessWidget {
  const AdminContestDrawWinnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance.collection('contests').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Contest Draw Winners')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final contests = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            return data['drawCompleted'] == true;
          }).toList()
            ..sort((a, b) {
              final aTime = (a.data()['drawCompletedAt'] as Timestamp?)
                  ?.millisecondsSinceEpoch ??
                  0;
              final bTime = (b.data()['drawCompletedAt'] as Timestamp?)
                  ?.millisecondsSinceEpoch ??
                  0;
              return bTime.compareTo(aTime);
            });

          if (contests.isEmpty) {
            return Center(
              child: Text(
                context.tr('No contest draw winners yet.'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final contest = contests[index];
              final data = contest.data();
              final title = (data['title'] ?? '').toString();
              final count = ((data['drawWinnerCount'] ?? 0) as num).toInt();
              final voters = ((data['drawEligibleVoterCount'] ?? 0) as num)
                  .toInt();
              final dt = (data['drawCompletedAt'] as Timestamp?)?.toDate();
              final timeText = dt == null
                  ? ''
                  : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _AdminContestDrawWinnerDetailScreen(
                        contestId: contest.id,
                        title: title,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.hotPink.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: AppColors.hotPink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.tr('Lucky Draw Winners')}: $count • ${context.tr('Eligible Voters')}: $voters',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                            if (timeText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${context.tr('Draw Completed At')}: $timeText',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('draw_winners')
        .orderBy('position')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                context.tr('No contest draw winners yet.'),
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final position = ((data['position'] ?? 0) as num).toInt();
              final userName = (data['userName'] ?? context.tr('User'))
                  .toString();
              final userEmail = (data['userEmail'] ?? '').toString();
              final userId = (data['userId'] ?? '').toString();
              final prize = ((data['prizeAmount'] ?? 10) as num)
                  .toDouble()
                  .toStringAsFixed(0);
              final dt = (data['drawAt'] as Timestamp?)?.toDate();
              final timeText = dt == null
                  ? ''
                  : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return Container(
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
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.hotPink.withValues(alpha: 0.18),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '\$$prize',
                          style: const TextStyle(
                            color: AppColors.sunset,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${context.tr('User ID')}: $userId',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('Email')}: $userEmail',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                    if (timeText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('Draw Completed At')}: $timeText',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
