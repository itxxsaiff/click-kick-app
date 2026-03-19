import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/report_video_dialog.dart';
import 'video_upload_screen.dart';

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
                    maxVideos: maxVideos,
                    focusSubmissionId: focusSubmissionId,
                  )
                : stage == ContestStage.completed
                ? _WinnersPage(
                    contestId: contestId,
                    title: title,
                    description: desc,
                    logoUrl: logoUrl,
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
                        _StageCard(stage: stage),
                        const SizedBox(height: 20),
                        if (stage == ContestStage.submissionOpen)
                          GradientButton(
                            label: 'Submit Video',
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
                            label: 'Coming Soon',
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
  });

  final String contestId;
  final String title;
  final String description;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final approvedStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: approvedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList();
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
                  context.tr('No approved videos found for this contest.'),
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
              (d) => ((d.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
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
              return _HeroCard(
                title: title,
                description: description,
                logoUrl: logoUrl,
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
    this.focusSubmissionId,
  });

  final String contestId;
  final String title;
  final String description;
  final String logoUrl;
  final int maxVideos;
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: approvedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
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
            _HeroCard(title: title, description: description, logoUrl: logoUrl),
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
  });

  final String contestId;
  final String userId;
  final String contestTitle;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> submissions;
  final String? focusSubmissionId;

  @override
  Widget build(BuildContext context) {
    final voteDocStream = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('votes')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: voteDocStream,
      builder: (context, voteSnapshot) {
        final votedSubmissionId =
            (voteSnapshot.data?.data()?['submissionId'] ?? '').toString();

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
            ? 1
            : width < 900
            ? 2
            : 3;
        final mainAxisExtent = width < 430
            ? 350.0
            : width < 900
            ? 340.0
            : 320.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: orderedSubmissions.length,
          itemBuilder: (context, index) {
            final doc = orderedSubmissions[index];
            final data = doc.data();
            final videoUrl = (data['videoUrl'] ?? '').toString();
            final ownerUserId = (data['userId'] ?? '').toString();
            final votes = ((data['voteCount'] ?? 0) as num).toInt();
            final isVoted = votedSubmissionId == doc.id;
            final hasVoted = votedSubmissionId.isNotEmpty;
            final isOwnVideo = ownerUserId == userId;
            final isHighlighted = doc.id == focusSubmissionId;

            return ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.ondemand_video,
                        color: AppColors.hotPink,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ParticipantNameLabel(
                      ownerUserId: ownerUserId,
                      cachedName:
                          (data['userName'] ?? data['participantName'] ?? '')
                              .toString(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: AppColors.hotPink,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$votes ${context.tr('votes')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('Share'),
                          onPressed: () async {
                            final base = Uri.base.origin;
                            final link = '$base/#/contest-share?contestId=$contestId&submissionId=${doc.id}';
                            final text = '${context.tr('Vote for my video')}: $contestTitle\n$link';
                            try {
                              await doc.reference.update({
                                'shareCount': FieldValue.increment(1),
                                'lastSharedAt': Timestamp.fromDate(DateTime.now()),
                              });
                            } catch (_) {}
                            await Share.share(text, subject: contestTitle);
                          },
                          icon: const Icon(
                            Icons.share_rounded,
                            color: AppColors.hotPink,
                            size: 20,
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('Report Video'),
                          onPressed: () => showReportVideoDialog(
                            context: context,
                            videoType: 'participant_video',
                            contestId: contestId,
                            submissionId: doc.id,
                            targetUserId: ownerUserId,
                            contestTitle: contestTitle,
                            participantName:
                                (data['userName'] ??
                                        data['participantName'] ??
                                        '')
                                    .toString(),
                          ),
                          icon: const Icon(
                            Icons.flag_outlined,
                            color: AppColors.hotPink,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: videoUrl.isEmpty
                            ? null
                            : () async {
                                if (!context.mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (_) =>
                                      _VideoPlayerDialog(videoUrl: videoUrl),
                                );
                              },
                        icon: const Icon(Icons.play_circle_fill),
                        label: Text(context.tr('Watch')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.cardSoft,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isOwnVideo
                            ? null
                            : hasVoted && !isVoted
                            ? null
                            : () => _castVote(
                                context: context,
                                contestId: contestId,
                                userId: userId,
                                submissionId: doc.id,
                                alreadyVoted: hasVoted,
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOwnVideo
                              ? AppColors.cardSoft
                              : isVoted
                              ? const Color(0xFF2DAF6F)
                              : AppColors.hotPink,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          isOwnVideo
                              ? context.tr('Your Video')
                              : isVoted
                              ? context.tr('Voted')
                              : context.tr('Vote Now'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _castVote({
    required BuildContext context,
    required String contestId,
    required String userId,
    required String submissionId,
    required bool alreadyVoted,
  }) async {
    if (alreadyVoted) {
      _snack(context, context.tr('You already voted in this contest.'));
      return;
    }

    final contestRef = FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId);
    final voteRef = contestRef.collection('votes').doc(userId);
    final submissionRef = contestRef
        .collection('submissions')
        .doc(submissionId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final voteSnap = await tx.get(voteRef);
        if (voteSnap.exists) {
          throw Exception('already-voted');
        }

        final subSnap = await tx.get(submissionRef);
        if (!subSnap.exists) {
          throw Exception('submission-not-found');
        }

        final status = (subSnap.data()?['status'] ?? '').toString();
        if (status != 'approved') {
          throw Exception('submission-not-approved');
        }
        final submissionOwnerId = (subSnap.data()?['userId'] ?? '').toString();
        if (submissionOwnerId == userId) {
          throw Exception('cannot-self-vote');
        }

        final now = Timestamp.fromDate(DateTime.now());
        tx.set(voteRef, {
          'contestId': contestId,
          'submissionId': submissionId,
          'voterId': userId,
          'createdAt': now,
        });
        tx.update(submissionRef, {
          'voteCount': FieldValue.increment(1),
          'updatedAt': now,
        });
      });

      _snack(context, context.tr('Vote submitted successfully.'));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('already-voted')) {
        _snack(context, context.tr('You already voted in this contest.'));
      } else if (msg.contains('cannot-self-vote')) {
        _snack(context, context.tr('You cannot vote for your own video.'));
      } else {
        _snack(context, context.tr('Vote failed. Please retry.'));
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  return Column(
                    children: [
                      SizedBox(
                        width: playerWidth,
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: VideoPlayer(_controller),
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
  });

  final String title;
  final String description;
  final String logoUrl;

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
  const _StageCard({required this.stage});

  final ContestStage stage;

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
      default:
        title = context.tr('Upcoming');
        subtitle = context.tr('Contest starts soon. Stay tuned.');
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
      stream: FirebaseFirestore.instance.collection('contests').doc(contestId).snapshots(),
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
