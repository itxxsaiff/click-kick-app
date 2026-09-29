import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../services/short_link_service.dart';
import '../../services/video_download_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/report_video_dialog.dart';
import '../../widgets/block_participant_dialog.dart';
import '../../widgets/blocked_users_builder.dart';
import '../profile/general_video_player_screen.dart' show openVideoWithRetry;
import 'video_upload_screen.dart';

Rect _shareOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
  final offset = renderObject.localToGlobal(Offset.zero);
  final size = renderObject.size;
  final width = size.width <= 0 ? 1.0 : size.width;
  final height = size.height <= 0 ? 1.0 : size.height;
  return Rect.fromLTWH(offset.dx, offset.dy, width, height);
}

class ContestDetailScreen extends StatelessWidget {
  const ContestDetailScreen({
    super.key,
    required this.contestId,
    required this.data,
    this.focusSubmissionId,
  });

  final String contestId;
  final Map<String, dynamic> data;
  final String? focusSubmissionId;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '') as String;
    final desc = (data['description'] ?? '') as String;
    final logoUrl = (data['logoUrl'] ?? '') as String;
    final contestNumber = (data['contestNumber'] ?? '').toString();
    final winnerPrize = ((data['winnerPrize'] ?? 100) as num).toDouble();
    final challengeQuestion = (data['challengeQuestion'] ?? '').toString();
    final contestVideoUrl = (data['contestVideoUrl'] ?? '').toString();
    final maxVideos = ((data['maxVideos'] ?? 0) as num).toInt();
    final submissionStart = _readDate(data['submissionStart']);
    final submissionEnd = _readDate(data['submissionEnd']);
    final votingStart = _readDate(data['votingStart']);
    final votingEnd = _readDate(data['votingEnd']);
    final now = DateTime.now();

    final stage = _contestStage(
      now,
      submissionStart,
      submissionEnd,
      votingStart,
      votingEnd,
    );

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: stage == ContestStage.votingOpen
                ? _VotingPage(
                    contestId: contestId,
                    title: title,
                    description: desc,
                    logoUrl: logoUrl,
                    contestNumber: contestNumber,
                    maxVideos: maxVideos,
                    focusSubmissionId: focusSubmissionId,
                  )
                : stage == ContestStage.completed
                ? _WinnersPage(
                    contestId: contestId,
                    title: title,
                    description: desc,
                    logoUrl: logoUrl,
                    contestNumber: contestNumber,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('Contest Details'),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _HeroCard(
                          title: title,
                          description: desc,
                          logoUrl: logoUrl,
                          contestNumber: contestNumber,
                        ),
                        const SizedBox(height: 12),
                        if (contestVideoUrl.isNotEmpty) ...[
                          _ContestScriptVideoCard(videoUrl: contestVideoUrl),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppColors.sunset,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (challengeQuestion.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Challenge: $challengeQuestion',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _TimelineCard(
                          submissionStart: submissionStart,
                          submissionEnd: submissionEnd,
                          votingStart: votingStart,
                          votingEnd: votingEnd,
                        ),
                        const SizedBox(height: 18),
                        _StageCard(
                          stage: stage,
                          submissionStart: submissionStart,
                        ),
                        if (stage == ContestStage.submissionOpen) ...[
                          const SizedBox(height: 20),
                          _SubmissionsBrowseSection(
                            contestId: contestId,
                            contestTitle: title,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (stage == ContestStage.submissionOpen)
                          GradientButton(
                            label: context.tr('Join Contest'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoUploadScreen(
                                    contestId: contestId,
                                    contestTitle: title,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          GradientButton(
                            label: context.tr('Coming Soon'),
                            onPressed: () {},
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _onOrAfter(DateTime a, DateTime b) => !a.isBefore(b);
  bool _onOrBefore(DateTime a, DateTime b) => !a.isAfter(b);
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  ContestStage _contestStage(
    DateTime now,
    DateTime? submissionStart,
    DateTime? submissionEnd,
    DateTime? votingStart,
    DateTime? votingEnd,
  ) {
    final normalizedSubmissionStart = submissionStart == null
        ? null
        : _startOfDay(submissionStart);
    final normalizedSubmissionEnd = submissionEnd == null
        ? null
        : _endOfDay(submissionEnd);
    final normalizedVotingStart = votingStart == null
        ? null
        : _startOfDay(votingStart);
    final normalizedVotingEnd = votingEnd == null ? null : _endOfDay(votingEnd);

    // Voting takes priority if submission and voting windows overlap.
    if (normalizedVotingStart != null && normalizedVotingEnd != null) {
      if (_onOrAfter(now, normalizedVotingStart) &&
          _onOrBefore(now, normalizedVotingEnd)) {
        return ContestStage.votingOpen;
      }
      if (now.isAfter(normalizedVotingEnd)) {
        return ContestStage.completed;
      }
    }
    if (normalizedSubmissionStart != null &&
        now.isBefore(normalizedSubmissionStart)) {
      return ContestStage.upcoming;
    }
    if (normalizedSubmissionStart != null && normalizedSubmissionEnd != null) {
      if (_onOrAfter(now, normalizedSubmissionStart) &&
          _onOrBefore(now, normalizedSubmissionEnd)) {
        return ContestStage.submissionOpen;
      }
    }
    return ContestStage.upcoming;
  }
}

enum ContestStage { upcoming, submissionOpen, votingOpen, completed }

class _WinnersPage extends StatelessWidget {
  const _WinnersPage({
    required this.contestId,
    required this.title,
    required this.description,
    required this.logoUrl,
    this.contestNumber = '',
  });

  final String contestId;
  final String title;
  final String description;
  final String logoUrl;
  final String contestNumber;

  @override
  Widget build(BuildContext context) {
    final approvedStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return BlockedUsersBuilder(
      builder: (context, blockedUserIds) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: approvedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs
                  .where(
                    (d) => !blockedUserIds.contains(
                      (d.data()['userId'] ?? '').toString(),
                    ),
                  )
                  .toList();
              if (docs.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Winners',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HeroCard(
                      title: title,
                      description: description,
                      logoUrl: logoUrl,
                      contestNumber: contestNumber,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        context.tr(
                          'No approved videos found for this contest.',
                        ),
                      ),
                    ),
                  ],
                );
              }

              int maxVotes = 0;
              for (final d in docs) {
                final v = ((d.data()['voteCount'] ?? 0) as num).toInt();
                if (v > maxVotes) maxVotes = v;
              }
              final winners = docs
                  .where(
                    (d) =>
                        ((d.data()['voteCount'] ?? 0) as num).toInt() ==
                        maxVotes,
                  )
                  .toList();

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: winners.length + 2,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Winners',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    );
                  }
                  if (index == 1) {
                    return Column(
                      children: [
                        _HeroCard(
                          title: title,
                          description: description,
                          logoUrl: logoUrl,
                          contestNumber: contestNumber,
                        ),
                        const SizedBox(height: 12),
                        _LuckyDrawWinnersSection(contestId: contestId),
                      ],
                    );
                  }
                  final doc = winners[index - 2];
                  final data = doc.data();
                  final userId = (data['userId'] ?? '').toString();
                  final videoUrl = (data['videoUrl'] ?? '').toString();
                  final votes = ((data['voteCount'] ?? 0) as num).toInt();

                  return _WinnerCard(
                    userId: userId,
                    votes: votes,
                    videoUrl: videoUrl,
                  );
                },
              );
            },
          ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.userId,
    required this.votes,
    required this.videoUrl,
  });

  final String userId;
  final int votes;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Winner Highlight'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sunset.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: AppColors.sunset,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('WINNER'),
                      style: const TextStyle(
                        color: AppColors.sunset,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.hotPink.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$votes ${context.tr('votes')}',
                  style: const TextStyle(
                    color: AppColors.hotPink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, snap) {
              final userName =
                  (snap.data?.data()?['displayName'] ??
                          snap.data?.data()?['email'] ??
                          userId)
                      .toString();
              return Text(
                '${context.tr('Winner')}: $userName',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _InlineWinnerVideo(videoUrl: videoUrl),
        ],
      ),
    );
  }
}

class _LuckyDrawWinnersSection extends StatelessWidget {
  const _LuckyDrawWinnersSection({required this.contestId});

  final String contestId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('draw_winners')
        .orderBy('position')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Lucky Draw Winners'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Five random voters win \$10 each for this contest.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Text(
                  context.tr(
                    'Lucky draw winners will appear after the contest ends.',
                  ),
                  style: const TextStyle(color: AppColors.textMuted),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();
                  final position = ((data['position'] ?? 0) as num).toInt();
                  final userName = (data['userName'] ?? context.tr('User'))
                      .toString();
                  final prize = ((data['prizeAmount'] ?? 10) as num)
                      .toDouble()
                      .toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.hotPink.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
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
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _InlineWinnerVideo extends StatefulWidget {
  const _InlineWinnerVideo({required this.videoUrl});

  final String videoUrl;

  @override
  State<_InlineWinnerVideo> createState() => _InlineWinnerVideoState();
}

class _InlineWinnerVideoState extends State<_InlineWinnerVideo> {
  VideoPlayerController? _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      _initFuture = _controller!.initialize();
      _controller!.setLooping(true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _initFuture == null) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(context.tr('Winner video not available.'))),
      );
    }

    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!_controller!.value.isInitialized) {
          return Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cardSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(context.tr('Unable to load winner video.')),
            ),
          );
        }

        return Column(
          children: [
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: VideoPlayer(_controller!),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () async {
                    final position = _controller!.value.position;
                    await _controller!.seekTo(
                      position - const Duration(seconds: 5),
                    );
                  },
                  icon: const Icon(Icons.replay_5, color: AppColors.textLight),
                ),
                IconButton(
                  onPressed: () {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                    setState(() {});
                  },
                  icon: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    color: AppColors.hotPink,
                    size: 34,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final position = _controller!.value.position;
                    await _controller!.seekTo(
                      position + const Duration(seconds: 5),
                    );
                  },
                  icon: const Icon(Icons.forward_5, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _VotingPage extends StatelessWidget {
  const _VotingPage({
    required this.contestId,
    required this.title,
    required this.description,
    required this.logoUrl,
    required this.maxVideos,
    this.contestNumber = '',
    this.focusSubmissionId,
  });

  final String contestId;
  final String title;
  final String description;
  final String logoUrl;
  final int maxVideos;
  final String contestNumber;
  final String? focusSubmissionId;

  @override
  Widget build(BuildContext context) {
    final approvedStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return BlockedUsersBuilder(
      builder: (context, blockedUserIds) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: approvedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs =
                  snapshot.data!.docs
                      .where(
                        (d) => !blockedUserIds.contains(
                          (d.data()['userId'] ?? '').toString(),
                        ),
                      )
                      .toList()
                    ..sort((a, b) {
                      final av = ((a.data()['voteCount'] ?? 0) as num).toInt();
                      final bv = ((b.data()['voteCount'] ?? 0) as num).toInt();
                      return bv.compareTo(av);
                    });

              final readyForVoting = maxVideos > 0 && docs.length >= maxVideos;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Live Voting'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _HeroCard(
                    title: title,
                    description: description,
                    logoUrl: logoUrl,
                    contestNumber: contestNumber,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        color: AppColors.hotPink,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${docs.length} ${context.tr('Videos')}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.how_to_vote, color: AppColors.hotPink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            readyForVoting
                                ? context.tr(
                                    'Pick your favorite video. You can vote only once in this contest.',
                                  )
                                : '${context.tr('Voting opens when approved videos reach max limit')}: ($maxVideos). ${context.tr('Current approved')}: ${docs.length}.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!readyForVoting)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(context.tr('Voting is not ready yet.')),
                    )
                  else if (uid == null)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(context.tr('Please login to vote.')),
                    )
                  else
                    _VotingGrid(
                      contestId: contestId,
                      userId: uid,
                      contestTitle: title,
                      submissions: docs,
                      focusSubmissionId: focusSubmissionId,
                    ),
                ],
              );
            },
          ),
    );
  }
}

/// Shown while submissions are open but voting has not started: the video
/// count so far, and a view-only grid of this contest's own approved videos
/// (no vote button yet). Keeps videos scoped to this one contest, so a
/// participant always knows exactly which contest they're looking at.
class _SubmissionsBrowseSection extends StatelessWidget {
  const _SubmissionsBrowseSection({
    required this.contestId,
    required this.contestTitle,
  });

  final String contestId;
  final String contestTitle;

  @override
  Widget build(BuildContext context) {
    final approvedStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .where('status', isEqualTo: 'approved')
        .snapshots();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return BlockedUsersBuilder(
      builder: (context, blockedUserIds) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: approvedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs
                  .where(
                    (d) => !blockedUserIds.contains(
                      (d.data()['userId'] ?? '').toString(),
                    ),
                  )
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        color: AppColors.hotPink,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${docs.length} ${context.tr('Videos')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        context.tr(
                          'No videos submitted yet. Be the first to join!',
                        ),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  else
                    _VotingGrid(
                      contestId: contestId,
                      userId: uid,
                      contestTitle: contestTitle,
                      submissions: docs,
                      allowVoting: false,
                    ),
                ],
              );
            },
          ),
    );
  }
}

/// Shown in a grid tile until a real thumbnail frame is generated for that
/// video (new uploads get one within moments of finishing; older uploads
/// from before this feature never had one captured).
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

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
    );
  }
}

class _VotingGrid extends StatelessWidget {
  const _VotingGrid({
    required this.contestId,
    required this.userId,
    required this.contestTitle,
    required this.submissions,
    this.focusSubmissionId,
    this.allowVoting = true,
  });

  final String contestId;

  /// Null for a signed-out visitor just browsing (only allowed when
  /// [allowVoting] is false, e.g. while submissions are still open).
  final String? userId;
  final String contestTitle;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions;
  final String? focusSubmissionId;

  /// False while submissions are open but voting has not started yet: shows
  /// the videos to browse, with no vote button.
  final bool allowVoting;

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (!allowVoting || uid == null) {
      return _buildGrid(context, const <String>{});
    }
    // One user + one video = one vote: a user can vote for every video in the
    // contest, but only once for each. Vote docs carry `voterId` and
    // `submissionId` (legacy one-vote-per-contest docs do too).
    final voteStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('votes')
        .where('voterId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: voteStream,
      builder: (context, voteSnapshot) {
        final votedSubmissionIds = <String>{
          for (final voteDoc in voteSnapshot.data?.docs ?? const [])
            (voteDoc.data()['submissionId'] ?? '').toString(),
        };
        return _buildGrid(context, votedSubmissionIds);
      },
    );
  }

  Widget _buildGrid(BuildContext context, Set<String> votedSubmissionIds) {
    final orderedSubmissions = submissions.toList();
    if ((focusSubmissionId ?? '').isNotEmpty) {
      orderedSubmissions.sort((a, b) {
        final aMatch = a.id == focusSubmissionId;
        final bMatch = b.id == focusSubmissionId;
        if (aMatch == bMatch) return 0;
        return aMatch ? -1 : 1;
      });
    }

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 430
        ? 2
        : width < 900
        ? 3
        : 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: orderedSubmissions.length,
      itemBuilder: (context, index) {
        final doc = orderedSubmissions[index];
        final data = doc.data();
        final votes = ((data['voteCount'] ?? 0) as num).toInt();
        final thumbnailUrl = (data['thumbnailUrl'] ?? '').toString();
        final participantName =
            (data['userName'] ?? data['participantName'] ?? '').toString();

        // A simple thumbnail preview, TikTok-style: no per-tile actions.
        // Tapping opens the full-screen video with Vote / Share / Report /
        // Block, matching how every other video plays in this app.
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ContestVideoScreen(
                contestId: contestId,
                contestTitle: contestTitle,
                userId: userId,
                allowVoting: allowVoting,
                submissions: orderedSubmissions,
                initialIndex: index,
                votedSubmissionIds: votedSubmissionIds,
              ),
            ),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnailUrl.isNotEmpty)
                  Image.network(
                    thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ThumbnailPlaceholder(),
                  )
                else
                  const _ThumbnailPlaceholder(),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC100A1E)],
                      stops: [0.55, 1],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (participantName.isNotEmpty)
                        Text(
                          participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 12,
                            color: AppColors.hotPink,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$votes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
  }
}

/// Full-screen video, TikTok-style: no modal, no card, just the video with
/// Vote / Share / Report / Block on the right and the name at the bottom.
/// Swipe up/down to move between this contest's other videos.
class _ContestVideoScreen extends StatefulWidget {
  const _ContestVideoScreen({
    required this.contestId,
    required this.contestTitle,
    required this.userId,
    required this.allowVoting,
    required this.submissions,
    required this.initialIndex,
    required this.votedSubmissionIds,
  });

  final String contestId;
  final String contestTitle;
  final String? userId;
  final bool allowVoting;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions;
  final int initialIndex;
  final Set<String> votedSubmissionIds;

  @override
  State<_ContestVideoScreen> createState() => _ContestVideoScreenState();
}

class _ContestVideoScreenState extends State<_ContestVideoScreen> {
  late final PageController _pageController;
  late int _index;
  late final Set<String> _votedSubmissionIds;
  VideoPlayerController? _controller;
  String _currentUrl = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _votedSubmissionIds = Set.of(widget.votedSubmissionIds);
    _pageController = PageController(initialPage: _index);
    _loadVideo(widget.submissions[_index]);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final url = (doc.data()['videoUrl'] ?? '').toString();
    if (url.isEmpty || url == _currentUrl) return;
    setState(() => _loading = true);
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    try {
      final controller = await openVideoWithRetry(url);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      _currentUrl = url;
      _controller = controller;
      await controller.play();
    } catch (_) {
      // Left unplayed; the page shows a loading spinner rather than a broken
      // player, matching the rest of the app's tolerance for a bad load.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.submissions.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _loadVideo(widget.submissions[i]);
            },
            itemBuilder: (context, i) {
              final doc = widget.submissions[i];
              final isActive = i == _index;
              final ready =
                  isActive &&
                  _controller != null &&
                  _controller!.value.isInitialized;
              return _ContestVideoPage(
                doc: doc,
                contestId: widget.contestId,
                contestTitle: widget.contestTitle,
                userId: widget.userId,
                allowVoting: widget.allowVoting,
                isVoted: _votedSubmissionIds.contains(doc.id),
                controller: ready ? _controller : null,
                isPlaying: ready && _controller!.value.isPlaying,
                isLoading: isActive && (_loading || !ready),
                onTapVideo: ready ? _togglePlayback : null,
                onVoted: () => setState(() => _votedSubmissionIds.add(doc.id)),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestVideoPage extends StatelessWidget {
  const _ContestVideoPage({
    required this.doc,
    required this.contestId,
    required this.contestTitle,
    required this.userId,
    required this.allowVoting,
    required this.isVoted,
    required this.controller,
    required this.isPlaying,
    required this.isLoading,
    required this.onVoted,
    this.onTapVideo,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String contestId;
  final String contestTitle;
  final String? userId;
  final bool allowVoting;
  final bool isVoted;
  final VideoPlayerController? controller;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback onVoted;
  final VoidCallback? onTapVideo;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _vote(BuildContext context) async {
    if (userId == null) {
      _snack(context, context.tr('Please login to vote.'));
      return;
    }
    if (isVoted) {
      _snack(context, context.tr('You already voted for this video.'));
      return;
    }
    try {
      await AuthService().incrementContestVote(
        contestId: contestId,
        submissionId: doc.id,
      );
      onVoted();
      if (context.mounted) {
        _snack(
          context,
          context.tr(
            'Your vote has been counted successfully. You are now entered into the lucky draw.',
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      if (e is FirebaseFunctionsException) {
        if (e.code == 'already-exists') {
          _snack(context, context.tr('You already voted for this video.'));
          return;
        }
        final details = (e.message ?? '').toString();
        if (details.contains('own video')) {
          _snack(context, context.tr('You cannot vote for your own video.'));
          return;
        }
        if (details.contains('not started yet')) {
          _snack(context, context.tr('Voting has not started yet.'));
          return;
        }
        if (details.contains('already ended')) {
          _snack(context, context.tr('Voting has already ended.'));
          return;
        }
      }
      final msg = e.toString();
      if (msg.contains('already-voted')) {
        _snack(context, context.tr('You already voted for this video.'));
      } else if (msg.contains('cannot-self-vote')) {
        _snack(context, context.tr('You cannot vote for your own video.'));
      } else if (msg.contains('Voting has not started yet')) {
        _snack(context, context.tr('Voting has not started yet.'));
      } else if (msg.contains('Voting has already ended')) {
        _snack(context, context.tr('Voting has already ended.'));
      } else {
        _snack(context, context.tr('Vote failed. Please retry.'));
      }
    }
  }

  Future<void> _share(BuildContext context, String participantName) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please login to share.'))),
      );
      return;
    }
    String link;
    try {
      link = await ShortLinkService().contestShareLink(
        contestId: contestId,
        submissionId: doc.id,
      );
    } catch (_) {
      link =
          '${ShortLinkService.shareBaseUrl}/contest?contestId=$contestId&submissionId=${doc.id}';
    }
    if (!context.mounted) return;
    try {
      await doc.reference.update({
        'shareCount': FieldValue.increment(1),
        'lastSharedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {}
    await Share.share(
      '${context.tr('Vote for my video')}: $contestTitle\n$link',
      subject: contestTitle,
      sharePositionOrigin: _shareOriginForContext(context),
    );
  }

  Future<void> _download(BuildContext context, String downloadUrl) async {
    final result = await VideoDownloadService.saveVideo(
      videoUrl: downloadUrl,
      fileName: 'clickkick_${doc.id}',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(result.messageKey))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final ownerUserId = (data['userId'] ?? '').toString();
    final participantName = (data['userName'] ?? data['participantName'] ?? '')
        .toString();
    final votes = ((data['voteCount'] ?? 0) as num).toInt();
    final shares = ((data['shareCount'] ?? 0) as num).toInt();
    final isOwnVideo = userId != null && ownerUserId == userId;
    final rawVideoUrl = (data['videoUrl'] ?? '').toString();
    final watermarkedVideoUrl = (data['watermarkedVideoUrl'] ?? '').toString();
    final downloadUrl = watermarkedVideoUrl.isNotEmpty
        ? watermarkedVideoUrl
        : rawVideoUrl;

    return GestureDetector(
      onTap: onTapVideo,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            )
          else if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.hotPink),
            )
          else
            const SizedBox.shrink(),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD0100A1E)],
                stops: [0.5, 1],
              ),
            ),
          ),
          if (controller != null)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (isPlaying || isLoading) ? 0 : 1,
                child: const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.hotPink,
                    size: 72,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allowVoting)
                  _ContestVideoAction(
                    icon: Icons.how_to_vote_rounded,
                    iconColor: isVoted ? const Color(0xFF2DAF6F) : Colors.white,
                    value: '$votes',
                    label: context.tr('Vote'),
                    onTap: isOwnVideo ? null : () => _vote(context),
                  ),
                const SizedBox(height: 18),
                _ContestVideoAction(
                  icon: Icons.share_outlined,
                  value: '$shares',
                  label: context.tr('Shares'),
                  onTap: () => _share(context, participantName),
                ),
                const SizedBox(height: 18),
                _ContestVideoAction(
                  icon: Icons.download_outlined,
                  label: context.tr('Save'),
                  onTap: () => _download(context, downloadUrl),
                ),
                const SizedBox(height: 18),
                _ContestVideoAction(
                  icon: Icons.flag_outlined,
                  label: context.tr('Report'),
                  onTap: () => showReportVideoDialog(
                    context: context,
                    videoType: 'participant_video',
                    contestId: contestId,
                    submissionId: doc.id,
                    targetUserId: ownerUserId,
                    contestTitle: contestTitle,
                    participantName: participantName,
                  ),
                ),
                if (!isOwnVideo) ...[
                  const SizedBox(height: 18),
                  _ContestVideoAction(
                    icon: Icons.block,
                    label: context.tr('Block'),
                    onTap: () => showBlockParticipantDialog(
                      context: context,
                      blockedUserId: ownerUserId,
                      contestId: contestId,
                      submissionId: doc.id,
                      contestTitle: contestTitle,
                      participantName: participantName,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 90,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🏆 $contestTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.hotPink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _ParticipantNameLabel(
                  ownerUserId: ownerUserId,
                  cachedName: participantName,
                ),
                const SizedBox(height: 4),
                Text(
                  '$votes ${context.tr('votes')}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _ContestVideoAction extends StatelessWidget {
  const _ContestVideoAction({
    required this.icon,
    required this.label,
    this.value,
    this.iconColor = Colors.white,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 4),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          SizedBox(
            width: 58,
            child: Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantNameLabel extends StatelessWidget {
  const _ParticipantNameLabel({
    required this.ownerUserId,
    required this.cachedName,
  });

  final String ownerUserId;
  final String cachedName;

  bool get _hasResolvedName =>
      cachedName.trim().isNotEmpty && cachedName.trim() != ownerUserId.trim();

  @override
  Widget build(BuildContext context) {
    if (_hasResolvedName || ownerUserId.isEmpty) {
      return Text(
        _hasResolvedName ? cachedName : context.tr('Participant'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUserId)
          .get(),
      builder: (context, snap) {
        final resolved = (snap.data?.data()?['displayName'] ?? '')
            .toString()
            .trim();
        return Text(
          resolved.isNotEmpty ? resolved : context.tr('Participant'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      },
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    final playerWidth = maxWidth > 720 ? 720.0 : maxWidth;
    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Watch Video'),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<void>(
                future: _initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (!_controller.value.isInitialized) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(context.tr('Unable to load video.')),
                    );
                  }
                  final videoAspect = _controller.value.aspectRatio > 0
                      ? _controller.value.aspectRatio
                      : 9 / 16;
                  final maxHeight = MediaQuery.sizeOf(context).height * 0.6;
                  var displayWidth = playerWidth;
                  var displayHeight = displayWidth / videoAspect;
                  if (displayHeight > maxHeight) {
                    displayHeight = maxHeight;
                    displayWidth = displayHeight * videoAspect;
                  }
                  return Column(
                    children: [
                      Container(
                        width: displayWidth,
                        height: displayHeight,
                        color: Colors.black,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onTap: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                              setState(() {});
                            },
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: _controller.value.size.width,
                                height: _controller.value.size.height,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () async {
                              final position = _controller.value.position;
                              await _controller.seekTo(
                                position - const Duration(seconds: 5),
                              );
                            },
                            icon: const Icon(
                              Icons.replay_5,
                              color: AppColors.textLight,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              color: AppColors.hotPink,
                              size: 34,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final position = _controller.value.position;
                              await _controller.seekTo(
                                position + const Duration(seconds: 5),
                              );
                            },
                            icon: const Icon(
                              Icons.forward_5,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContestScriptVideoCard extends StatelessWidget {
  const _ContestScriptVideoCard({required this.videoUrl});

  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Contest Video Brief'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Watch the official contest video before uploading.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () async {
              if (!context.mounted) return;
              await showDialog<void>(
                context: context,
                barrierDismissible: true,
                builder: (_) => _VideoPlayerDialog(videoUrl: videoUrl),
              );
            },
            icon: const Icon(Icons.play_circle_fill),
            label: Text(context.tr('Watch Contest Video')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cardSoft,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.description,
    required this.logoUrl,
    this.contestNumber = '',
  });

  final String title;
  final String description;
  final String logoUrl;
  final String contestNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
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
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(logoUrl, fit: BoxFit.cover),
                  )
                : const Icon(
                    Icons.emoji_events,
                    color: AppColors.hotPink,
                    size: 32,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contestNumber.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.hotPink.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${context.tr('Competition')} #$contestNumber',
                      style: const TextStyle(
                        color: AppColors.hotPink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.submissionStart,
    required this.submissionEnd,
    required this.votingStart,
    required this.votingEnd,
  });

  final DateTime? submissionStart;
  final DateTime? submissionEnd;
  final DateTime? votingStart;
  final DateTime? votingEnd;

  String _fmt(DateTime? date) {
    if (date == null) return '--';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Timeline'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _line(context.tr('Submission Start'), _fmt(submissionStart)),
          _line(context.tr('Submission End'), _fmt(submissionEnd)),
          _line(context.tr('Voting Start'), _fmt(votingStart)),
          _line(context.tr('Voting End'), _fmt(votingEnd)),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Text(value, style: const TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, this.submissionStart});

  final ContestStage stage;
  final DateTime? submissionStart;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    Color accent;

    switch (stage) {
      case ContestStage.submissionOpen:
        title = context.tr('Submission Open');
        subtitle = context.tr('Upload your best 30-45s video now.');
        accent = AppColors.neonGreen;
        break;
      case ContestStage.votingOpen:
        title = context.tr('Voting Live');
        subtitle = context.tr('Watch and vote for your favorites.');
        accent = AppColors.hotPink;
        break;
      case ContestStage.completed:
        title = context.tr('Contest Completed');
        subtitle = context.tr('Winner announced. View results.');
        accent = AppColors.sunset;
        break;
      case ContestStage.upcoming:
        title = context.tr('Submissions have not started yet');
        final start = submissionStart;
        subtitle = start == null
            ? context.tr('Check back soon for the opening date.')
            : '${context.tr('Submissions open on')} ${_formatDate(start)}.';
        accent = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.bolt, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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

class ContestShareRouteScreen extends StatelessWidget {
  const ContestShareRouteScreen({
    super.key,
    required this.contestId,
    this.focusSubmissionId,
  });

  final String contestId;
  final String? focusSubmissionId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contests')
          .doc(contestId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.deepSpace),
            body: Center(child: Text(context.tr('Unable to load contest.'))),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.deepSpace),
            body: Center(child: Text(context.tr('Contest not found.'))),
          );
        }
        return ContestDetailScreen(
          contestId: contestId,
          data: data,
          focusSubmissionId: focusSubmissionId,
        );
      },
    );
  }
}
