import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import 'contest_detail_screen.dart';

/// All competitions as a grid of equal-size cards. Tapping one opens
/// [ContestDetailScreen], which shows only that competition's own submitted
/// videos — competitions are never mixed together, so a participant always
/// knows exactly which contest they are viewing or submitting to.
class ContestListScreen extends StatefulWidget {
  const ContestListScreen({
    super.key,
    this.embedded = false,
    this.sharedContestId,
  });

  /// When true, renders without its own back button, so it can be hosted
  /// inside the public feed's tab shell (the shell already draws the title).
  final bool embedded;

  /// Set when opened from a shared contest link: that contest's detail page
  /// is opened automatically once the list has loaded.
  final String? sharedContestId;

  @override
  State<ContestListScreen> createState() => _ContestListScreenState();
}

class _ContestListScreenState extends State<ContestListScreen> {
  bool _openedShared = false;

  void _maybeOpenShared(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sharedId = widget.sharedContestId;
    if (_openedShared || sharedId == null || sharedId.isEmpty) return;
    QueryDocumentSnapshot<Map<String, dynamic>>? match;
    for (final doc in docs) {
      if (doc.id == sharedId) {
        match = doc;
        break;
      }
    }
    final matchedDoc = match;
    if (matchedDoc == null) return;
    _openedShared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContestDetailScreen(
            contestId: matchedDoc.id,
            data: matchedDoc.data(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final contests = FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true);

    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

        final nowSort = DateTime.now();
        DateTime? readContestDate(dynamic value) {
          if (value is Timestamp) return value.toDate();
          if (value is String) return DateTime.tryParse(value);
          return null;
        }

        docs.sort((a, b) {
          final ad = a.data();
          final bd = b.data();
          final aStart = readContestDate(ad['submissionStart']);
          final bStart = readContestDate(bd['submissionStart']);
          final aEnd =
              readContestDate(ad['votingEnd']) ??
              readContestDate(ad['submissionEnd']);
          final bEnd =
              readContestDate(bd['votingEnd']) ??
              readContestDate(bd['submissionEnd']);
          final aEnded = aEnd != null && aEnd.isBefore(nowSort);
          final bEnded = bEnd != null && bEnd.isBefore(nowSort);
          if (aEnded != bEnded) return aEnded ? 1 : -1;
          if (aStart == null && bStart == null) return 0;
          if (aStart == null) return 1;
          if (bStart == null) return -1;
          return aStart.compareTo(bStart);
        });

        _maybeOpenShared(docs);

        if (docs.isEmpty) {
          return Center(
            child: Text(
              context.tr('No contests available.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _CompetitionCard(
              title: (data['title'] ?? '').toString(),
              logoUrl: (data['logoUrl'] ?? '').toString(),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ContestDetailScreen(contestId: doc.id, data: data),
                ),
              ),
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              context.tr('Choose a competition and show your talent!'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Text(
                        context.tr('Competitions'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One equal-size competition card in the grid.
class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({
    required this.title,
    required this.logoUrl,
    required this.onTap,
  });

  final String title;
  final String logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (logoUrl.isNotEmpty)
              Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _CardPlaceholder(),
              )
            else
              const _CardPlaceholder(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE0100A1E)],
                  stops: [0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? context.tr('Contest') : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.hotPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSoft, AppColors.deepSpace],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.emoji_events_rounded,
          color: AppColors.hotPink,
          size: 40,
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
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
