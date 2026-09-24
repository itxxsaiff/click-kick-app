import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../services/follow_service.dart';
import '../../services/general_video_service.dart';
import '../../services/short_link_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/block_participant_dialog.dart';
import '../../widgets/follow_widgets.dart';
import '../../services/video_download_service.dart';
import '../../widgets/report_video_dialog.dart';
import 'follow_list_screen.dart';
import 'general_video_player_screen.dart';
import 'settings_screen.dart';

/// A user's profile: avatar, Videos / Followers / Following, and two tabs of
/// videos (General Videos and Competition Videos).
///
/// Used for the signed-in user's own Profile tab ([embedded] = true, no back
/// button) and, pushed on the navigator, for anyone else's profile.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.embedded = false,
  });

  final String userId;
  final bool embedded;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _CompetitionVideo {
  const _CompetitionVideo({
    required this.id,
    this.contestId = '',
    this.isWinner = false,
    required this.contestTitle,
    required this.status,
    required this.votes,
    required this.videoUrl,
    required this.createdAt,
    required this.rejectionReason,
  });

  final String id;
  final String contestId;
  final bool isWinner;
  final String contestTitle;
  final String status;
  final int votes;
  final String videoUrl;
  final DateTime createdAt;
  final String rejectionReason;
}

class _ProfileData {
  const _ProfileData({
    required this.user,
    required this.general,
    required this.competition,
    required this.followers,
    required this.following,
    required this.generalFailed,
    required this.competitionFailed,
  });

  final UserBrief user;
  final List<GeneralVideo> general;
  final List<_CompetitionVideo> competition;
  final int followers;
  final int following;
  final bool generalFailed;
  final bool competitionFailed;

  int get videosCount =>
      general.where((v) => v.isApproved).length +
      competition.where((v) => v.status == 'approved').length;
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _follow = FollowService();
  final _generalService = GeneralVideoService();
  late Future<_ProfileData> _future;
  int _tab = 0; // 0 = General Videos, 1 = Competition Videos.
  bool _photoBusy = false;

  bool get _isOwner => FirebaseAuth.instance.currentUser?.uid == widget.userId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<UserBrief> _loadUser() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final brief = UserBrief.fromMap(widget.userId, snap.data());
      if (_isOwner) {
        final auth = FirebaseAuth.instance.currentUser;
        return UserBrief(
          uid: brief.uid,
          name: brief.name.isNotEmpty ? brief.name : (auth?.displayName ?? ''),
          photoUrl: brief.photoUrl.isNotEmpty
              ? brief.photoUrl
              : (auth?.photoURL ?? ''),
          country: brief.country,
        );
      }
      return brief;
    } catch (_) {
      return UserBrief.empty(widget.userId);
    }
  }

  /// The user's competition entries, plus the contest titles for entries that
  /// do not carry one. Uses a single collection-group query, and falls back to
  /// asking each contest when that query is unavailable (for example, the
  /// collection-group index on `userId` has not been created yet).
  Future<
    ({
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      Map<String, String> titles,
    })
  >
  _competitionDocs() async {
    final firestore = FirebaseFirestore.instance;
    // Everyone else can only read approved entries (see the security rules), so
    // the queries have to say so.
    try {
      Query<Map<String, dynamic>> query = firestore
          .collectionGroup('submissions')
          .where('userId', isEqualTo: widget.userId);
      if (!_isOwner) {
        query = query.where('status', isEqualTo: 'approved');
      }
      final snap = await query.get();
      return (docs: snap.docs, titles: <String, String>{});
    } catch (e) {
      // The error text contains a link that creates the missing index.
      debugPrint('Competition videos: collection-group query failed: $e');
    }

    final contests = await firestore.collection('contests').get();
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final titles = <String, String>{};
    for (final contest in contests.docs) {
      Query<Map<String, dynamic>> query = contest.reference
          .collection('submissions')
          .where('userId', isEqualTo: widget.userId);
      if (!_isOwner) {
        query = query.where('status', isEqualTo: 'approved');
      }
      final snap = await query.get();
      if (snap.docs.isEmpty) continue;
      docs.addAll(snap.docs);
      titles[contest.id] = (contest.data()['title'] ?? '').toString();
    }
    return (docs: docs, titles: titles);
  }

  Future<List<_CompetitionVideo>> _loadCompetition() async {
    final result = await _competitionDocs();
    final videos = result.docs.map((doc) {
      final data = doc.data();
      final contestId =
          (data['contestId'] ?? doc.reference.parent.parent?.id ?? '')
              .toString();
      return _CompetitionVideo(
        id: doc.id,
        contestId: contestId,
        contestTitle:
            (data['contestTitle'] ??
                    data['contestName'] ??
                    result.titles[contestId] ??
                    '')
                .toString(),
        status: (data['status'] ?? 'pending').toString(),
        votes: ((data['voteCount'] ?? 0) as num).toInt(),
        videoUrl: (data['videoUrl'] ?? '').toString(),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
        rejectionReason: (data['rejectionReason'] ?? '').toString(),
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _isOwner ? _markWinners(videos) : videos;
  }

  /// Flags the owner's entries that won: the contest's voting has ended and
  /// the entry has the most votes among approved entries.
  Future<List<_CompetitionVideo>> _markWinners(
    List<_CompetitionVideo> videos,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final contestIds = videos
        .where((v) => v.status == 'approved' && v.contestId.isNotEmpty)
        .map((v) => v.contestId)
        .toSet();
    final winnerIds = <String>{};
    for (final contestId in contestIds) {
      try {
        final contest = await firestore
            .collection('contests')
            .doc(contestId)
            .get();
        final votingEnd = (contest.data()?['votingEnd'] as Timestamp?)
            ?.toDate();
        if (votingEnd == null || DateTime.now().isBefore(votingEnd)) continue;
        final approved = await contest.reference
            .collection('submissions')
            .where('status', isEqualTo: 'approved')
            .get();
        var maxVotes = 0;
        for (final doc in approved.docs) {
          final votes = ((doc.data()['voteCount'] ?? 0) as num).toInt();
          if (votes > maxVotes) maxVotes = votes;
        }
        if (maxVotes <= 0) continue;
        for (final doc in approved.docs) {
          final votes = ((doc.data()['voteCount'] ?? 0) as num).toInt();
          if (votes == maxVotes) winnerIds.add(doc.id);
        }
      } catch (_) {
        // A contest we cannot read just means no winner badge for it.
      }
    }
    return [
      for (final v in videos)
        winnerIds.contains(v.id)
            ? _CompetitionVideo(
                id: v.id,
                contestId: v.contestId,
                isWinner: true,
                contestTitle: v.contestTitle,
                status: v.status,
                votes: v.votes,
                videoUrl: v.videoUrl,
                createdAt: v.createdAt,
                rejectionReason: v.rejectionReason,
              )
            : v,
    ];
  }

  Future<_ProfileData> _load() async {
    // Start everything in parallel, then collect. A failing section degrades
    // to an empty result (with a retry hint for the video lists) instead of
    // breaking the whole page. Fallbacks are attached right away so a failure
    // is never left unhandled while another future is still being awaited.
    var generalFailed = false;
    var competitionFailed = false;
    final userF = _loadUser();
    final generalF = _generalService
        .loadForUser(widget.userId, isOwner: _isOwner)
        .catchError((_) {
          generalFailed = true;
          return <GeneralVideo>[];
        });
    final competitionF = _loadCompetition().catchError((_) {
      competitionFailed = true;
      return <_CompetitionVideo>[];
    });
    final followersF = _follow
        .followersCount(widget.userId)
        .catchError((_) => 0);
    final followingF = _follow
        .followingCount(widget.userId)
        .catchError((_) => 0);

    final general = await generalF;
    final competition = await competitionF;
    return _ProfileData(
      user: await userF,
      general: general,
      competition: competition,
      followers: await followersF,
      following: await followingF,
      generalFailed: generalFailed,
      competitionFailed: competitionFailed,
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _changePhoto() async {
    if (_photoBusy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final failMsg = context.tr(
      'Could not update your photo. Please try again.',
    );
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photoBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child(
        'profile_photos/${user.uid}/profile.jpg',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      // The storage path never changes, so add a version to bust image caches.
      final url =
          '${await ref.getDownloadURL()}&v=${DateTime.now().millisecondsSinceEpoch}';
      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': url,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      UserDirectory.invalidate(user.uid);
      await _reload();
    } catch (_) {
      _snack(failMsg);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _shareProfile(String name) async {
    String link;
    try {
      link = await ShortLinkService().profileLink(widget.userId);
    } catch (_) {
      link =
          '${GeneralVideoService.shareBaseUrl}/profile?userId=${widget.userId}';
    }
    if (!mounted) return;
    await Share.share('$name\nClick Kick\n$link', subject: name);
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    // Name / photo may have been edited inside Settings.
    UserDirectory.invalidate(widget.userId);
    if (mounted) await _reload();
  }

  Future<void> _openFollowList(FollowListMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(userId: widget.userId, mode: mode),
      ),
    );
    // Follows may have changed inside the list.
    if (mounted) await _reload();
  }

  Future<void> _deleteVideo(GeneralVideo video) async {
    final failMsg = context.tr('Could not delete the video. Please try again.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Delete Video')),
        content: Text(
          dialogContext.tr('Are you sure you want to delete this video?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _generalService.delete(video);
      await _reload();
    } catch (_) {
      _snack(failMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<_ProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr('Unable to load the profile.')),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _reload,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, data)),
              SliverToBoxAdapter(child: _buildTabs(context)),
              ..._buildTabContent(context, data),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(child: body),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _ProfileData data) {
    final name = data.user.name.isNotEmpty
        ? data.user.name
        : context.tr('User');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embedded)
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _shareProfile(name),
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                ),
                if (!_isOwner && FirebaseAuth.instance.currentUser != null)
                  PopupMenuButton<String>(
                    color: AppColors.card,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (_) async {
                      final blocked = await showBlockParticipantDialog(
                        context: context,
                        blockedUserId: widget.userId,
                        participantName: name,
                      );
                      if (blocked && mounted) Navigator.maybePop(this.context);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'block',
                        child: Text(context.tr('Block')),
                      ),
                    ],
                  ),
              ],
            )
          else
            const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(data.user),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      icon: Icons.play_circle_outline_rounded,
                      value: data.videosCount,
                      label: context.tr('Videos'),
                    ),
                    _StatRow(
                      icon: Icons.people_alt_rounded,
                      value: data.followers,
                      label: context.tr('Followers'),
                      onTap: () => _openFollowList(FollowListMode.followers),
                    ),
                    _StatRow(
                      icon: Icons.person_add_alt_1_rounded,
                      value: data.following,
                      label: context.tr('Following'),
                      onTap: () => _openFollowList(FollowListMode.following),
                    ),
                  ],
                ),
              ),
              if (widget.embedded)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _shareProfile(name),
                      icon: const Icon(
                        Icons.share_outlined,
                        color: AppColors.hotPink,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _openSettings,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.settings_outlined,
                          color: AppColors.hotPink,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                )
              else if (_isOwner)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.settings_outlined,
                          color: AppColors.hotPink,
                          size: 30,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('Settings'),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (!_isOwner) ...[
            const SizedBox(height: 14),
            FollowButton(
              targetUserId: widget.userId,
              width: double.infinity,
              height: 42,
              onChanged: (_) => _reload(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(UserBrief user) {
    // Tapping the avatar itself changes the photo (owner only) — no separate
    // "+" badge needed, so it doesn't eat into the header for no reason.
    return GestureDetector(
      onTap: _isOwner ? _changePhoto : null,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          children: [
            Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.hotPink, Color(0xFF7B3FF2)],
                ),
              ),
              child: UserAvatar(photoUrl: user.photoUrl, size: 96),
            ),
            if (_photoBusy)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    Widget pill(int index, IconData icon, String label) {
      final selected = _tab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = index),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected
                  ? const LinearGradient(
                      colors: [AppColors.hotPink, Color(0xFFB12EDB)],
                    )
                  : null,
              color: selected ? null : AppColors.card.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? AppColors.hotPink
                    : AppColors.border.withValues(alpha: 0.9),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          pill(0, Icons.video_library_rounded, context.tr('General Videos')),
          const SizedBox(width: 10),
          pill(
            1,
            Icons.emoji_events_outlined,
            context.tr('Competition Videos'),
          ),
        ],
      ),
    );
  }

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 0.78,
  );

  List<Widget> _buildTabContent(BuildContext context, _ProfileData data) {
    final isGeneral = _tab == 0;
    final failed = isGeneral ? data.generalFailed : data.competitionFailed;
    final count = isGeneral ? data.general.length : data.competition.length;

    return [
      // Aggregate stats across the videos this viewer can see (approved-only
      // for a non-owner, everything for the owner) — same idea as a TikTok /
      // Facebook page's public totals.
      if (isGeneral && !failed && count > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _SummaryChip(
                  value: data.general.fold<int>(
                    0,
                    (acc, v) => acc + v.viewCount,
                  ),
                  label: context.tr('Views'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  value: data.general.fold<int>(
                    0,
                    (acc, v) => acc + v.likeCount,
                  ),
                  label: context.tr('Likes'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  value: data.general.fold<int>(
                    0,
                    (acc, v) => acc + v.shareCount,
                  ),
                  label: context.tr('Shares'),
                ),
              ],
            ),
          ),
        ),
      if (!isGeneral && _isOwner && !failed && count > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _SummaryChip(
                  value: data.competition.length,
                  label: context.tr('Total Videos'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  value: data.competition
                      .where((v) => v.status == 'approved')
                      .length,
                  label: context.tr('Approved'),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  value: data.competition.where((v) => v.isWinner).length,
                  label: context.tr('Winner'),
                ),
              ],
            ),
          ),
        ),
      if (failed)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  context.tr('Unable to load videos. Tap retry.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _reload,
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          ),
        )
      else if (count == 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              isGeneral
                  ? context.tr('No general videos yet.')
                  : context.tr('No competition videos yet.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: _gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) => isGeneral
                  ? _generalTile(context, data.general[index], data.user)
                  : _competitionTile(context, data.competition[index]),
              childCount: count,
            ),
          ),
        ),
    ];
  }

  /// Downloads [videoUrl] to the device (web: opens it for the browser's own
  /// download; mobile: saves to the gallery). No watermark is added — that is
  /// a separate, not-yet-built feature.
  Future<void> _download(String videoUrl, String fileName) async {
    final result = await VideoDownloadService.saveVideo(
      videoUrl: videoUrl,
      fileName: fileName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr(result.messageKey)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _generalTile(
    BuildContext context,
    GeneralVideo video,
    UserBrief user,
  ) {
    return _VideoTile(
      views: video.viewCount,
      statusBadge: video.isApproved
          ? null
          : _statusBadge(context, video.status),
      onTap: video.videoUrl.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GeneralVideoPlayerScreen(video: video),
              ),
            ),
      menu: PopupMenuButton<String>(
        color: AppColors.card,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        onSelected: (value) {
          if (value == 'delete') {
            _deleteVideo(video);
          } else if (value == 'download') {
            _download(video.videoUrl, 'clickkick_${video.id}');
          } else if (value == 'report') {
            showReportVideoDialog(
              context: context,
              videoType: 'general_video',
              submissionId: video.id,
              targetUserId: video.userId,
              participantName: user.name,
            );
          }
        },
        itemBuilder: (context) => [
          if (_isOwner) ...[
            PopupMenuItem(
              value: 'download',
              child: Text(context.tr('Download')),
            ),
            PopupMenuItem(value: 'delete', child: Text(context.tr('Delete'))),
          ] else
            PopupMenuItem(value: 'report', child: Text(context.tr('Report'))),
        ],
      ),
    );
  }

  Widget _competitionTile(BuildContext context, _CompetitionVideo video) {
    final status = video.isWinner ? 'winner' : video.status;
    return _VideoTile(
      statusBadge: status == 'approved' ? null : _statusBadge(context, status),
      title: video.contestTitle,
      note: video.status == 'rejected' ? video.rejectionReason : '',
      votes: video.votes,
      onTap: video.videoUrl.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SimpleVideoPlayerScreen(
                  videoUrl: video.videoUrl,
                  title: video.contestTitle,
                ),
              ),
            ),
      menu: _isOwner && video.videoUrl.isNotEmpty
          ? PopupMenuButton<String>(
              color: AppColors.card,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              onSelected: (_) =>
                  _download(video.videoUrl, 'clickkick_${video.id}'),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'download',
                  child: Text(context.tr('Download')),
                ),
              ],
            )
          : null,
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final (color, label) = switch (status) {
      'rejected' => (const Color(0xFFC53D5D), context.tr('Rejected')),
      'winner' => (AppColors.hotPink, context.tr('Winner')),
      _ => (AppColors.sunset, context.tr('Pending')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.hotPink, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              child: Text(
                formatCount(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One video in a profile grid. General videos show a view count and a ⋮
/// menu; competition entries show the contest title and votes.
class _VideoTile extends StatelessWidget {
  const _VideoTile({
    this.views,
    this.votes,
    this.title = '',
    this.note = '',
    this.statusBadge,
    this.menu,
    this.onTap,
  });

  final int? views;
  final int? votes;
  final String title;
  final String note;
  final Widget? statusBadge;
  final Widget? menu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardSoft, AppColors.card],
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.hotPink,
                size: 38,
              ),
            ),
            if (statusBadge != null)
              Positioned(top: 8, left: 8, child: statusBadge!),
            if (menu != null)
              Positioned(top: 0, right: 0, width: 34, height: 34, child: menu!),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  if (note.isNotEmpty)
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                  if (views != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          formatCount(views!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (votes != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_vote_rounded,
                          color: AppColors.hotPink,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatCount(votes!),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
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
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
