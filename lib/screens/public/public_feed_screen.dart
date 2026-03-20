import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/report_video_dialog.dart';
import '../shared/legal_center_screen.dart';
import '../user/contest_detail_screen.dart';

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  int _tabIndex = 0;

  String _headerTitle(BuildContext context, List<String> labels, int safeIndex) {
    return context.tr(labels[safeIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final isLoggedIn = authSnapshot.data != null;
        final labels = isLoggedIn
            ? <String>['Home', 'Dashboard', 'Winners', 'Profile']
            : <String>['Home', 'Winners', 'Profile'];
        final icons = isLoggedIn
            ? <IconData>[
                Icons.home_outlined,
                Icons.dashboard_outlined,
                Icons.workspace_premium_outlined,
                Icons.person_outline,
              ]
            : <IconData>[
                Icons.home_outlined,
                Icons.workspace_premium_outlined,
                Icons.person_outline,
              ];
        final activeIcons = isLoggedIn
            ? <IconData>[
                Icons.home,
                Icons.dashboard_customize,
                Icons.workspace_premium,
                Icons.person,
              ]
            : <IconData>[
                Icons.home,
                Icons.workspace_premium,
                Icons.person,
              ];
        final pages = isLoggedIn
            ? const <Widget>[
                _HomeFeedTab(),
                _DashboardGateTab(),
                _WinnersFeedTab(),
                _ProfileGateTab(),
              ]
            : const <Widget>[
                _HomeFeedTab(),
                _WinnersFeedTab(),
                _ProfileGateTab(),
              ];

        final safeIndex = _tabIndex.clamp(0, labels.length - 1);
        if (_tabIndex != safeIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _tabIndex = safeIndex);
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              const _SpaceBackground(),
              SafeArea(
                child: Column(
                  children: [
                    if (safeIndex != 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(activeIcons[safeIndex], color: AppColors.hotPink),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _headerTitle(context, labels, safeIndex),
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const LanguageMenuButton(compact: true),
                          ],
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: safeIndex,
                        children: pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x221B1033), Color(0xCC130B25)],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A1847), Color(0xFF1C1232)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border.withOpacity(0.9)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BottomNavigationBar(
                  currentIndex: safeIndex,
                  onTap: (v) => setState(() => _tabIndex = v),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppColors.hotPink,
                  unselectedItemColor: AppColors.textMuted.withOpacity(0.95),
                  selectedFontSize: 13,
                  unselectedFontSize: 12,
                  items: List.generate(labels.length, (i) {
                    return BottomNavigationBarItem(
                      icon: Icon(icons[i]),
                      activeIcon: Icon(activeIcons[i]),
                      label: context.tr(labels[i]),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab();

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab> {
  final _pageController = PageController();
  int _activeIndex = 0;
  VideoPlayerController? _videoController;
  String _currentVideoUrl = '';
  String? _pendingVideoUrl;
  bool _pendingAutoplay = false;

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setActiveVideo(String url, {bool autoplay = true}) async {
    if (url.isEmpty || url == _currentVideoUrl) return;
    final old = _videoController;
    _videoController = null;
    _currentVideoUrl = url;
    if (mounted) setState(() {});
    await old?.pause();
    await old?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    await controller.setLooping(true);
    controller.addListener(() {
      if (!mounted) return;
      if (_currentVideoUrl != url) return;
      setState(() {});
    });
    if (autoplay) {
      await controller.play();
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _videoController = controller);
  }

  Future<void> _clearActiveVideo() async {
    if (_currentVideoUrl.isEmpty && _videoController == null) return;
    _currentVideoUrl = '';
    final old = _videoController;
    _videoController = null;
    await old?.pause();
    await old?.dispose();
    if (mounted) setState(() {});
  }

  void _scheduleActiveVideoSync(_FeedItem item, {required bool autoplay}) {
    final desiredUrl = item.hasVideo && item.videoUrl.isNotEmpty
        ? item.videoUrl
        : '';
    if (_pendingVideoUrl == desiredUrl && _pendingAutoplay == autoplay) return;
    _pendingVideoUrl = desiredUrl;
    _pendingAutoplay = autoplay;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final url = _pendingVideoUrl ?? '';
      final shouldAutoplay = _pendingAutoplay;
      _pendingVideoUrl = null;
      if (url.isEmpty) {
        await _clearActiveVideo();
        return;
      }
      if (url == _currentVideoUrl) return;
      await _setActiveVideo(url, autoplay: shouldAutoplay);
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('contests').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                context.tr(
                  'Unable to load home feed. Please check Firestore rules/indexes.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final contests = snap.data!.docs.where((e) {
          final d = e.data();
          final videoUrl = (d['contestVideoUrl'] ?? '').toString();
          final status = (d['status'] ?? '').toString();
          return videoUrl.isNotEmpty && status == 'live';
        }).toList()
          ..sort((a, b) {
            final ad = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bd = (b.data()['createdAt'] as Timestamp?)?.toDate();
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('news')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, newsSnapshot) {
            if (newsSnapshot.hasError) {
              return Center(
                child: Text(
                  context.tr('Unable to load news.'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            if (!newsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_videos')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, adminVideosSnapshot) {
                if (adminVideosSnapshot.hasError) {
                  return Center(
                    child: Text(
                      context.tr('Unable to load feed videos.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                if (!adminVideosSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final newsDocs = newsSnapshot.data!.docs;
                final adminVideoDocs = adminVideosSnapshot.data!.docs;
                final feedItems = _buildFeedItems(
                  contests,
                  newsDocs,
                  adminVideoDocs,
                );

                if (feedItems.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('No live contests yet.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final safeIndex = _activeIndex.clamp(0, feedItems.length - 1);
                final activeItem = feedItems[safeIndex];
                _scheduleActiveVideoSync(activeItem, autoplay: false);

                return PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  itemCount: feedItems.length,
                  onPageChanged: (i) async {
                    setState(() => _activeIndex = i);
                    final item = feedItems[i];
                    if (item.hasVideo && item.videoUrl.isNotEmpty) {
                      await _setActiveVideo(item.videoUrl, autoplay: false);
                    } else {
                      await _clearActiveVideo();
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = feedItems[index];
                    if (item.isNews) {
                      return _NewsFeedCard(item: item);
                    }
                    if (item.isAdminVideo) {
                      final isActive = index == safeIndex;
                      final isShowingActiveVideo =
                          isActive &&
                          _videoController != null &&
                          _videoController!.value.isInitialized &&
                          _currentVideoUrl == item.videoUrl;
                      final isPlaying = isShowingActiveVideo &&
                          _videoController!.value.isPlaying;
                      return _AdminVideoFeedCard(
                        item: item,
                        isShowingActiveVideo: isShowingActiveVideo,
                        isPlaying: isPlaying,
                        controller: _videoController,
                        onTapVideo: isShowingActiveVideo ? _togglePlayback : null,
                      );
                    }

                    final doc = item.contestDoc!;
                    final data = doc.data();
                    final title = item.title;
                    final description = item.description;
                    final contestType =
                        (data['contestType'] ?? 'video_contest').toString();
                    final winnerPrize = item.winnerPrize;
                    final logoUrl = item.logoUrl;
                    final videoUrl = item.videoUrl;
                    final isActive = index == safeIndex;
                    final isShowingActiveVideo =
                        isActive &&
                        _videoController != null &&
                        _videoController!.value.isInitialized &&
                        _currentVideoUrl == videoUrl;
                    final isPlaying =
                        isShowingActiveVideo && _videoController!.value.isPlaying;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: GestureDetector(
                      onTap: isShowingActiveVideo ? _togglePlayback : null,
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isShowingActiveVideo)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            )
                          else
                            Container(
                              color: AppColors.card,
                              child: const Center(
                                child: Icon(
                                  Icons.ondemand_video_rounded,
                                  color: AppColors.hotPink,
                                  size: 64,
                                ),
                              ),
                            ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xD0100A1E)],
                                stops: [0.45, 1],
                              ),
                            ),
                          ),
                          if (isShowingActiveVideo)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 180),
                                opacity: isPlaying ? 0 : 1,
                                child: Center(
                                  child: Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.32),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.22),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 16,
                            right: 14,
                            child: IconButton(
                              onPressed: () async {
                                final text = '$title\n$description\n$videoUrl';
                                await Share.share(text, subject: title);
                              },
                              icon: const Icon(Icons.share_rounded),
                            ),
                          ),
                          Positioned(
                            top: 64,
                            right: 14,
                            child: IconButton(
                              onPressed: () => showReportVideoDialog(
                                context: context,
                                videoType: 'contest_video',
                                contestId: doc.id,
                                targetUserId: (data['sponsorId'] ?? '').toString(),
                                contestTitle: title,
                              ),
                              icon: const Icon(Icons.flag_outlined),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.cardSoft,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: contestType == 'sponsor_contest' &&
                                              logoUrl.isNotEmpty
                                          ? Image.network(
                                              logoUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.campaign,
                                                    color: AppColors.hotPink,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.verified,
                                              color: AppColors.hotPink,
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${context.tr('Winner Prize')}: \$${winnerPrize.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.sunset,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user == null) {
                                        Navigator.pushNamed(context, '/login');
                                        return;
                                      }
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.hotPink,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(context.tr('Join Contest')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<_FeedItem> _buildFeedItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> contests,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> newsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> adminVideoDocs,
  ) {
    final items = <_FeedItem>[];
    final supplemental = <_FeedItem>[
      ...newsDocs.map(_FeedItem.fromNews),
      ...adminVideoDocs.map(_FeedItem.fromAdminVideo),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var contestIndex = 0;
    var supplementalIndex = 0;

    while (contestIndex < contests.length ||
        supplementalIndex < supplemental.length) {
      for (var i = 0; i < 2 && contestIndex < contests.length; i++) {
        items.add(_FeedItem.fromContest(contests[contestIndex]));
        contestIndex++;
      }
      if (supplementalIndex < supplemental.length) {
        items.add(supplemental[supplementalIndex]);
        supplementalIndex++;
      }
    }

    return items;
  }
}

class _FeedItem {
  const _FeedItem({
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.contestDoc,
    this.imageUrl = '',
    this.logoUrl = '',
    this.videoUrl = '',
    this.winnerPrize = 0,
    this.adminName = '',
    this.adminVideoId = '',
  });

  final String type;
  final String title;
  final String description;
  final DateTime createdAt;
  final QueryDocumentSnapshot<Map<String, dynamic>>? contestDoc;
  final String imageUrl;
  final String logoUrl;
  final String videoUrl;
  final double winnerPrize;
  final String adminName;
  final String adminVideoId;

  bool get isContest => type == 'contest';
  bool get isNews => type == 'news';
  bool get isAdminVideo => type == 'admin_video';
  bool get hasVideo => isContest || isAdminVideo;

  factory _FeedItem.fromContest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _FeedItem(
      type: 'contest',
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      contestDoc: doc,
      logoUrl: (data['logoUrl'] ?? '').toString(),
      videoUrl: (data['contestVideoUrl'] ?? '').toString(),
      winnerPrize: ((data['winnerPrize'] ?? 100) as num).toDouble(),
    );
  }

  factory _FeedItem.fromNews(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _FeedItem(
      type: 'news',
      title: (data['title'] ?? '').toString(),
      description: ((data['details'] ?? data['body']) ?? '').toString(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      imageUrl: (data['imageUrl'] ?? '').toString(),
    );
  }

  factory _FeedItem.fromAdminVideo(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _FeedItem(
      type: 'admin_video',
      title: (data['adminName'] ?? 'Admin').toString(),
      description: (data['caption'] ?? '').toString(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      adminName: (data['adminName'] ?? 'Admin').toString(),
      adminVideoId: doc.id,
    );
  }
}

class _NewsFeedCard extends StatefulWidget {
  const _NewsFeedCard({required this.item});

  final _FeedItem item;

  @override
  State<_NewsFeedCard> createState() => _NewsFeedCardState();
}

class _AdminVideoFeedCard extends StatelessWidget {
  const _AdminVideoFeedCard({
    required this.item,
    required this.isShowingActiveVideo,
    required this.isPlaying,
    required this.controller,
    this.onTapVideo,
  });

  final _FeedItem item;
  final bool isShowingActiveVideo;
  final bool isPlaying;
  final VideoPlayerController? controller;
  final VoidCallback? onTapVideo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: GestureDetector(
          onTap: onTapVideo,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isShowingActiveVideo && controller != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                )
              else
                Container(
                  color: AppColors.card,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.hotPink,
                      size: 72,
                    ),
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD0100A1E)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              if (isShowingActiveVideo)
                IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: isPlaying ? 0 : 1,
                    child: Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 16,
                right: 14,
                child: IconButton(
                  onPressed: () async {
                    final text = '${item.adminName}\n${item.description}\n${item.videoUrl}';
                    await Share.share(text, subject: item.adminName);
                  },
                  icon: const Icon(Icons.share_rounded),
                ),
              ),
              Positioned(
                top: 64,
                right: 14,
                child: IconButton(
                  onPressed: () => showReportVideoDialog(
                    context: context,
                    videoType: 'admin_video',
                    adminVideoId: item.adminVideoId,
                    contestTitle: item.adminName,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF66D7FF).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF66D7FF).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        context.tr('Admin Video'),
                        style: const TextStyle(
                          color: Color(0xFF66D7FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: AppColors.hotPink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsFeedCardState extends State<_NewsFeedCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: AppColors.card,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF0E0818)),
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.22),
                    child: item.imageUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.newspaper_rounded,
                              color: AppColors.hotPink,
                              size: 70,
                            ),
                          )
                        : Image.network(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMuted,
                                size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD0100A1E)],
                    stops: [0.48, 1],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 14,
                child: IconButton(
                  onPressed: () async {
                    final text = '${item.title}\n${item.description}';
                    await Share.share(text, subject: item.title);
                  },
                  icon: const Icon(Icons.share_rounded),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hotPink.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.hotPink.withOpacity(0.45),
                        ),
                      ),
                      child: Text(
                        context.tr('News Update'),
                        style: const TextStyle(
                          color: AppColors.hotPink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.newspaper_rounded,
                            color: AppColors.hotPink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    if (item.description.trim().length > 120) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          context.tr(_expanded ? 'Read less' : 'Read more'),
                          style: const TextStyle(
                            color: AppColors.hotPink,
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
        ),
      ),
    );
  }
}

class _DashboardGateTab extends StatelessWidget {
  const _DashboardGateTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _LoginRequiredCard();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final role = (snapshot.data!.data()?['role'] ?? 'user').toString();
        if (role == 'user' || role == 'participant') {
          return _ParticipantDashboardTab(userId: user.uid);
        }
        return Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.dashboard_customize, size: 44, color: AppColors.hotPink),
                const SizedBox(height: 10),
                Text(
                  context.tr('Open your role dashboard.'),
                  style: const TextStyle(color: AppColors.textLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                  child: Text(context.tr('Open Dashboard')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantDashboardTab extends StatefulWidget {
  const _ParticipantDashboardTab({required this.userId});

  final String userId;

  @override
  State<_ParticipantDashboardTab> createState() => _ParticipantDashboardTabState();
}

class _ParticipantDashboardTabState extends State<_ParticipantDashboardTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _errorMessage;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final firestore = FirebaseFirestore.instance;
    try {
      final snap = await firestore
          .collectionGroup('submissions')
          .where('userId', isEqualTo: widget.userId)
          .get()
          .timeout(const Duration(seconds: 15));

      final docs = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;
        data['contestId'] =
            (data['contestId'] ?? doc.reference.parent.parent?.id ?? '').toString();
        data['isWinner'] = false;
        return data;
      }).toList();
      return _markOwnWinners(docs, firestore);
    } catch (_) {
      final contests = await firestore
          .collection('contests')
          .get()
          .timeout(const Duration(seconds: 15));
      final out = <Map<String, dynamic>>[];
      for (final contest in contests.docs) {
        final subSnap = await contest.reference
            .collection('submissions')
            .where('userId', isEqualTo: widget.userId)
            .get()
            .timeout(const Duration(seconds: 15));
        for (final sub in subSnap.docs) {
          final data = Map<String, dynamic>.from(sub.data());
          data['contestId'] = contest.id;
          data['contestName'] = (contest.data()['title'] ?? '').toString();
          data['_docId'] = sub.id;
          data['isWinner'] = false;
          out.add(data);
        }
      }
      return _markOwnWinners(out, firestore);
    }
  }

  Future<List<Map<String, dynamic>>> _markOwnWinners(
    List<Map<String, dynamic>> docs,
    FirebaseFirestore firestore,
  ) async {
    if (docs.isEmpty) return docs;
    final now = DateTime.now();
    final contestIds = docs
        .map((d) => (d['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final contestId in contestIds) {
      final contestDoc = await firestore.collection('contests').doc(contestId).get();
      if (!contestDoc.exists) continue;
      final votingEnd = (contestDoc.data()?['votingEnd'] as Timestamp?)?.toDate();
      if (votingEnd == null || now.isBefore(votingEnd)) continue;

      final submissionsSnap = await contestDoc.reference
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get()
          .timeout(const Duration(seconds: 15));
      if (submissionsSnap.docs.isEmpty) continue;

      var maxVotes = 0;
      for (final sub in submissionsSnap.docs) {
        final votes = ((sub.data()['voteCount'] ?? 0) as num).toInt();
        if (votes > maxVotes) maxVotes = votes;
      }
      final winnerIds = submissionsSnap.docs
          .where((sub) => ((sub.data()['voteCount'] ?? 0) as num).toInt() == maxVotes)
          .map((sub) => sub.id)
          .toSet();

      for (final doc in docs) {
        if ((doc['contestId'] ?? '').toString() != contestId) continue;
        if ((doc['status'] ?? '').toString() != 'approved') continue;
        final docId = (doc['_docId'] ?? '').toString();
        if (winnerIds.contains(docId)) {
          doc['isWinner'] = true;
        }
      }
    }
    return docs;
  }

  Future<void> _refresh() async {
    setState(() {
      _errorMessage = null;
      _future = _load();
    });
    try {
      await _future;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('Dashboard request timed out. Check internet and retry.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('Unable to load dashboard data. Tap retry.');
      });
    }
  }

  String _t(BuildContext context, String key, String arFallback) {
    final value = context.tr(key);
    if (context.isArabic && (value == key || RegExp(r'^[A-Za-z]').hasMatch(value))) {
      return arFallback;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return Center(child: Text(context.tr('Please login.')));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _errorMessage == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_errorMessage != null || snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: AppColors.hotPink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ?? context.tr('Unable to load dashboard data. Tap retry.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = List<Map<String, dynamic>>.from(snapshot.data ?? <Map<String, dynamic>>[])
          ..sort((a, b) {
            final at = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });

        final filtered = _statusFilter == 'all'
            ? docs
            : _statusFilter == 'winner'
                ? docs.where((e) => e['isWinner'] == true).toList()
                : docs.where((e) => (e['status'] ?? '').toString() == _statusFilter).toList();

        final pending = docs.where((e) => (e['status'] ?? '') == 'pending').length;
        final approved = docs.where((e) => (e['status'] ?? '') == 'approved').length;
        final rejected = docs.where((e) => (e['status'] ?? '') == 'rejected').length;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.isEmpty ? 3 : filtered.length + 2,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(
                  children: [
                    _CountCard(
                      label: _t(context, 'Total', 'الإجمالي'),
                      value: docs.length,
                      color: AppColors.hotPink,
                    ),
                    const SizedBox(width: 8),
                    _CountCard(
                      label: _t(context, 'Pending', 'قيد الانتظار'),
                      value: pending,
                      color: AppColors.sunset,
                    ),
                    const SizedBox(width: 8),
                    _CountCard(
                      label: _t(context, 'Approved', 'مقبول'),
                      value: approved,
                      color: const Color(0xFF2DAF6F),
                    ),
                    const SizedBox(width: 8),
                    _CountCard(
                      label: _t(context, 'Rejected', 'مرفوض'),
                      value: rejected,
                      color: const Color(0xFFC53D5D),
                    ),
                  ],
                );
              }
              if (index == 1) {
                const options = ['all', 'pending', 'approved', 'rejected', 'winner'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(context, 'Filter by status', 'تصفية حسب الحالة'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: options.map((option) {
                          final isSelected = _statusFilter == option;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                _t(
                                  context,
                                  option[0].toUpperCase() + option.substring(1),
                                  switch (option) {
                                    'all' => 'الكل',
                                    'pending' => 'قيد الانتظار',
                                    'approved' => 'مقبول',
                                    'rejected' => 'مرفوض',
                                    _ => 'الفائز',
                                  },
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _statusFilter = option),
                              selectedColor: AppColors.hotPink.withOpacity(0.22),
                              backgroundColor: AppColors.card,
                              side: BorderSide(
                                color: isSelected ? AppColors.hotPink : AppColors.border,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.tr('No videos found for selected filter.')),
                  ),
                );
              }

              final data = filtered[index - 2];
              final status = (data['isWinner'] == true)
                  ? 'winner'
                  : (data['status'] ?? 'pending').toString();
              final reason = (data['rejectionReason'] ?? '').toString();
              final videoUrl = (data['videoUrl'] ?? '').toString();
              final contestName =
                  (data['contestName'] ?? data['contestTitle'] ?? data['contestId'] ?? '')
                      .toString();

              Color badge = AppColors.sunset;
              if (status == 'approved') badge = const Color(0xFF2DAF6F);
              if (status == 'rejected') badge = const Color(0xFFC53D5D);
              if (status == 'winner') badge = AppColors.hotPink;

              return Container(
                padding: const EdgeInsets.all(14),
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
                        Expanded(
                          child: Text(
                            '${_t(context, 'Contest', 'المسابقة')}: $contestName',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badge.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _t(
                              context,
                              status[0].toUpperCase() + status.substring(1),
                              switch (status) {
                                'approved' => 'مقبول',
                                'rejected' => 'مرفوض',
                                'winner' => 'الفائز',
                                _ => 'قيد الانتظار',
                              },
                            ),
                            style: TextStyle(
                              color: badge,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: videoUrl.isEmpty
                          ? null
                          : () async {
                              await showDialog<void>(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => _InlineVideoDialog(videoUrl: videoUrl),
                              );
                            },
                      icon: const Icon(Icons.play_circle_fill),
                      label: Text(_t(context, 'Watch Video', 'مشاهدة الفيديو')),
                    ),
                    if (status == 'rejected' && reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('${_t(context, 'Reason', 'السبب')}: $reason'),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _WinnersFeedTab extends StatelessWidget {
  const _WinnersFeedTab();

  Future<List<Map<String, dynamic>>> _load() async {
    final contests = await FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true)
        .get();
    final now = DateTime.now();
    final winners = <Map<String, dynamic>>[];
    for (final contest in contests.docs) {
      final c = contest.data();
      final votingEnd = (c['votingEnd'] as Timestamp?)?.toDate();
      if (votingEnd == null || votingEnd.isAfter(now)) continue;

      final subs = await FirebaseFirestore.instance
          .collection('contests')
          .doc(contest.id)
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get();
      if (subs.docs.isEmpty) continue;
      int maxVotes = -1;
      for (final s in subs.docs) {
        final v = ((s.data()['voteCount'] ?? 0) as num).toInt();
        if (v > maxVotes) maxVotes = v;
      }
      if (maxVotes <= 0) continue;
      final top = subs.docs.firstWhere(
        (s) => ((s.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
      );
      final t = top.data();
      winners.add({
        'contestTitle': (c['title'] ?? '').toString(),
        'logoUrl': (c['logoUrl'] ?? '').toString(),
        'winnerName': (t['userName'] ?? '').toString(),
        'videoUrl': (t['videoUrl'] ?? '').toString(),
        'votes': maxVotes,
      });
    }
    return winners;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              context.tr('No winners yet.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final w = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (w['logoUrl'] as String).isNotEmpty
                        ? Image.network(
                            w['logoUrl'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.workspace_premium,
                              color: AppColors.hotPink,
                            ),
                          )
                        : const Icon(
                            Icons.workspace_premium,
                            color: AppColors.hotPink,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (w['contestTitle'] ?? '').toString(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Winner')}: ${(w['winnerName'] ?? '').toString()}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(w['votes'] ?? 0).toString()} ${context.tr('votes')}',
                          style: const TextStyle(
                            color: AppColors.hotPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileGateTab extends StatelessWidget {
  const _ProfileGateTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _LoginRequiredCard();
    return _PublicUserProfileTab(user: user);
  }
}

class _PublicUserProfileTab extends StatefulWidget {
  const _PublicUserProfileTab({required this.user});

  final User user;

  @override
  State<_PublicUserProfileTab> createState() => _PublicUserProfileTabState();
}

class _PublicUserProfileTabState extends State<_PublicUserProfileTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _phoneCodeController = TextEditingController(text: '+1');
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String _phoneIso = 'US';
  bool _saving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    setState(() {
      _nameController.text = (data['displayName'] ?? _nameController.text).toString();
      _emailController.text = (data['email'] ?? _emailController.text).toString();
      _phoneCodeController.text = (data['phoneCountryCode'] ?? '+1').toString();
      _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
      _phoneNumberController.text = (data['phoneNumber'] ?? '').toString();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneCodeController.dispose();
    _phoneNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      final willUpdateEmail = newEmail.isNotEmpty && newEmail != (user.email ?? '');
      final willUpdatePassword = newPassword.isNotEmpty || confirmPassword.isNotEmpty;

      if (willUpdatePassword && newPassword != confirmPassword) {
        _show(context, context.tr('New password and confirm password do not match.'));
        return;
      }
      if ((willUpdateEmail || willUpdatePassword) && currentPassword.isEmpty) {
        _show(
          context,
          context.tr('Current password is required to update email or password.'),
        );
        return;
      }
      if (willUpdateEmail || willUpdatePassword) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);
      }

      await user.updateDisplayName(newName);
      if (willUpdateEmail) {
        await user.verifyBeforeUpdateEmail(newEmail);
      }
      if (willUpdatePassword && newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'email': user.email ?? '',
        'phoneCountryCode': _phoneCodeController.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumberController.text.trim(),
        'phoneE164':
            '${_phoneCodeController.text.trim()}${_phoneNumberController.text.trim()}',
        if (willUpdateEmail) 'pendingEmail': newEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (willUpdateEmail) {
        _show(
          context,
          context.tr('Verification email sent. Confirm it to complete email change.'),
        );
      } else {
        _show(context, context.tr('Profile updated successfully.'));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, context.tr('Current password is incorrect.'));
      } else if (e.code == 'email-already-in-use') {
        _show(context, context.tr('This email is already in use.'));
      } else if (e.code == 'weak-password') {
        _show(context, context.tr('New password is too weak.'));
      } else {
        _show(context, context.tr('Profile update failed (${e.code}).'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: context.tr('Full Name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: context.tr('Email')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (country) {
                            setState(() {
                              _phoneCodeController.text = '+${country.phoneCode}';
                              _phoneIso = country.countryCode;
                            });
                          },
                        );
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: context.tr('Code')),
                        child: Text(
                          '$_phoneIso ${_phoneCodeController.text}',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: TextField(
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: context.tr('Phone number')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.tr('Security'),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: context.tr('Current Password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureCurrentPassword = !_obscureCurrentPassword,
                    ),
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: context.tr('New Password (optional)'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: context.tr('Confirm New Password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _saving ? context.tr('Saving...') : context.tr('Update Profile'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalCenterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.privacy_tip_outlined),
            label: Text(context.tr('Legal & Privacy')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(context.tr('Logout')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB93A63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _show(BuildContext context, String message) {
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

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, size: 48, color: AppColors.hotPink),
            const SizedBox(height: 10),
            Text(
              user == null
                  ? context.tr('Login to manage your profile and contests.')
                  : (user.email ?? context.tr('Logged in user')),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            if (user == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.hotPink,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.tr('Login')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text(context.tr('Create account')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _InlineVideoDialog extends StatefulWidget {
  const _InlineVideoDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_InlineVideoDialog> createState() => _InlineVideoDialogState();
}

class _InlineVideoDialogState extends State<_InlineVideoDialog> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _controller != null && _controller!.value.isInitialized
            ? VideoPlayer(_controller!)
            : const Center(child: CircularProgressIndicator()),
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
            right: -80,
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
          colors: [color.withOpacity(0.55), color.withOpacity(0)],
        ),
      ),
    );
  }
}
