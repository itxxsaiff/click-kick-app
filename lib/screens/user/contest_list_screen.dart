import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import 'contest_detail_screen.dart';

class ContestListScreen extends StatelessWidget {
  const ContestListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final contests = FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('Active Contests'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.leaderboard),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: contests.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data();
                        final contestType = (data['contestType'] ?? 'video_contest')
                            .toString();
                        final status = (data['status'] ?? '').toString();
                        if (contestType == 'sponsor_contest') {
                          return status == 'live';
                        }
                        return true;
                      }).toList();
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(context.tr('No contests available.')),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final title = (data['title'] ?? '') as String;
                          final desc = (data['description'] ?? '') as String;
                          final logoUrl = (data['logoUrl'] ?? '') as String;
                          final winnerPrize =
                              ((data['winnerPrize'] ?? 100) as num).toDouble();

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContestDetailScreen(
                                    contestId: doc.id,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppColors.border),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x55000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSoft,
                                      borderRadius: BorderRadius.circular(18),
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
                                        : const Icon(
                                            Icons.emoji_events,
                                            color: AppColors.hotPink,
                                            size: 30,
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: AppColors.sunset,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.play_circle,
                                              size: 18,
                                              color: AppColors.hotPink,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.tr('View Contest'),
                                              style: const TextStyle(
                                                color: AppColors.hotPink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
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
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 160,
            right: -60,
            child: _GlowOrb(size: 220, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.55), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}
