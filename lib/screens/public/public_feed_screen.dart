import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/report_video_dialog.dart';
import '../../widgets/settings_action_tile.dart';
import '../../widgets/password_change_layout.dart';
import '../../main.dart';
import '../shared/legal_center_screen.dart';
import '../shared/click_kick_star_page.dart';
import '../shared/support_chat_screen.dart';
import '../user/contest_detail_screen.dart';
import '../auth/login_screen.dart';

const _shareBaseUrl = 'https://video-contest-show-b788b.firebaseapp.com';
final Set<Future<void> Function()> _feedStopHandlers =
    <Future<void> Function()>{};
bool _feedPlaybackLocked = false;

Future<void> stopAllFeedPlayback({bool lock = true}) async {
  if (lock) {
    _feedPlaybackLocked = true;
  }
  final handlers = List<Future<void> Function()>.from(_feedStopHandlers);
  for (final handler in handlers) {
    try {
      await handler();
    } catch (_) {}
  }
}

void unlockFeedPlayback() {
  _feedPlaybackLocked = false;
}

String _contestShareLink(String contestId, {String? submissionId}) {
  final params = <String, String>{'contestId': contestId};
  if (submissionId != null && submissionId.isNotEmpty) {
    params['submissionId'] = submissionId;
  }
  final query = Uri(queryParameters: params).query;
  return '$_shareBaseUrl/contest-share?$query';
}

String _feedVideoShareLink(String adminVideoId) {
  final query = Uri(queryParameters: {'videoId': adminVideoId}).query;
  return '$_shareBaseUrl/feed-video?$query';
}

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({
    super.key,
    this.initialTabIndex = 0,
    this.sharedContestId,
    this.sharedAdminVideoId,
  });

  final int initialTabIndex;
  final String? sharedContestId;
  final String? sharedAdminVideoId;

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
  }

  String _headerTitle(
    BuildContext context,
    List<String> labels,
    int safeIndex,
  ) {
    return context.tr(labels[safeIndex]);
  }

  Future<_PublicNavConfig> _loadNavConfig(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 8));
      final role = (userDoc.data()?['role'] ?? 'user').toString().toLowerCase();
      final isParticipant = role == 'participant';
      if (!isParticipant) {
        return const _PublicNavConfig(isParticipant: false, hasUploads: false);
      }

      try {
        final uploadSnap = await FirebaseFirestore.instance
            .collectionGroup('submissions')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        return _PublicNavConfig(
          isParticipant: true,
          hasUploads: uploadSnap.docs.isNotEmpty,
        );
      } catch (_) {
        return const _PublicNavConfig(isParticipant: true, hasUploads: false);
      }
    } catch (_) {
      return const _PublicNavConfig(isParticipant: false, hasUploads: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final isLoggedIn = authSnapshot.data != null;
        if (!isLoggedIn) {
          return _buildShell(
            context: context,
            labels: const <String>[
              'Home',
              'Contests',
              'Click Kick Star',
              'Sign',
            ],
            icons: const <IconData>[
              Icons.home_outlined,
              Icons.local_fire_department_outlined,
              Icons.star_outline_rounded,
              Icons.person_outline,
            ],
            activeIcons: const <IconData>[
              Icons.home,
              Icons.local_fire_department,
              Icons.star_rounded,
              Icons.person,
            ],
            pages: <Widget>[
              _HomeFeedTab(
                isVisible: _tabIndex == 0,
                sharedAdminVideoId: widget.sharedAdminVideoId,
              ),
              _PublicContestsTab(
                isVisible: _tabIndex == 1,
                sharedContestId: widget.sharedContestId,
              ),
              const ClickKickStarPage(),
              const _LoginRequiredCard(),
            ],
          );
        }

        final userId = authSnapshot.data!.uid;
        return FutureBuilder<_PublicNavConfig>(
          future: _loadNavConfig(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Scaffold(
                body: Stack(
                  children: [
                    _SpaceBackground(),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }

            final nav =
                snapshot.data ??
                const _PublicNavConfig(isParticipant: false, hasUploads: false);
            final labels = nav.isParticipant
                ? (nav.hasUploads
                      ? const <String>[
                          'Home',
                          'Contests',
                          'Click Kick Star',
                          'Dashboard',
                          'Profile',
                        ]
                      : const <String>[
                          'Home',
                          'Contests',
                          'Click Kick Star',
                          'Dashboard',
                          'Profile',
                        ])
                : const <String>[
                    'Home',
                    'Contests',
                    'Click Kick Star',
                    'Profile',
                  ];

            final icons = nav.isParticipant
                ? (nav.hasUploads
                      ? const <IconData>[
                          Icons.home_outlined,
                          Icons.local_fire_department_outlined,
                          Icons.star_outline_rounded,
                          Icons.dashboard_outlined,
                          Icons.person_outline,
                        ]
                      : const <IconData>[
                          Icons.home_outlined,
                          Icons.local_fire_department_outlined,
                          Icons.star_outline_rounded,
                          Icons.dashboard_outlined,
                          Icons.person_outline,
                        ])
                : const <IconData>[
                    Icons.home_outlined,
                    Icons.local_fire_department_outlined,
                    Icons.star_outline_rounded,
                    Icons.person_outline,
                  ];

            final activeIcons = nav.isParticipant
                ? (nav.hasUploads
                      ? const <IconData>[
                          Icons.home,
                          Icons.local_fire_department,
                          Icons.star_rounded,
                          Icons.dashboard_customize,
                          Icons.person,
                        ]
                      : const <IconData>[
                          Icons.home,
                          Icons.local_fire_department,
                          Icons.star_rounded,
                          Icons.dashboard_customize,
                          Icons.person,
                        ])
                : const <IconData>[
                    Icons.home,
                    Icons.local_fire_department,
                    Icons.star_rounded,
                    Icons.person,
                  ];

            final pages = nav.isParticipant
                ? (nav.hasUploads
                      ? <Widget>[
                          _HomeFeedTab(
                            isVisible: _tabIndex == 0,
                            sharedAdminVideoId: widget.sharedAdminVideoId,
                          ),
                          _PublicContestsTab(
                            isVisible: _tabIndex == 1,
                            sharedContestId: widget.sharedContestId,
                          ),
                          const ClickKickStarPage(),
                          const _DashboardGateTab(),
                          const _ProfileGateTab(),
                        ]
                      : <Widget>[
                          _HomeFeedTab(
                            isVisible: _tabIndex == 0,
                            sharedAdminVideoId: widget.sharedAdminVideoId,
                          ),
                          _PublicContestsTab(
                            isVisible: _tabIndex == 1,
                            sharedContestId: widget.sharedContestId,
                          ),
                          const ClickKickStarPage(),
                          const _DashboardGateTab(),
                          const _ProfileGateTab(),
                        ])
                : <Widget>[
                    _HomeFeedTab(
                      isVisible: _tabIndex == 0,
                      sharedAdminVideoId: widget.sharedAdminVideoId,
                    ),
                    _PublicContestsTab(
                      isVisible: _tabIndex == 1,
                      sharedContestId: widget.sharedContestId,
                    ),
                    const ClickKickStarPage(),
                    const _ProfileGateTab(),
                  ];

            return _buildShell(
              context: context,
              labels: labels,
              icons: icons,
              activeIcons: activeIcons,
              pages: pages,
            );
          },
        );
      },
    );
  }

  Widget _buildShell({
    required BuildContext context,
    required List<String> labels,
    required List<IconData> icons,
    required List<IconData> activeIcons,
    required List<Widget> pages,
  }) {
    final safeIndex = _tabIndex.clamp(0, labels.length - 1);
    final isImmersiveFeed = safeIndex == 0 || labels[safeIndex] == 'Contests';
    if (_tabIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = safeIndex);
      });
    }

    final bodyContent = Column(
      children: [
        if (!isImmersiveFeed)
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
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(index: safeIndex, children: pages),
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          if (isImmersiveFeed) bodyContent else SafeArea(child: bodyContent),
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
  }
}

class _PublicNavConfig {
  const _PublicNavConfig({
    required this.isParticipant,
    required this.hasUploads,
  });

  final bool isParticipant;
  final bool hasUploads;
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab({required this.isVisible, this.sharedAdminVideoId});

  final bool isVisible;
  final String? sharedAdminVideoId;

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab> with RouteAware {
  static const _watchedAdminVideosPrefsKey = 'watched_admin_videos_v1';
  final _pageController = PageController();
  final Set<String> _failedAdminVideoUrls = <String>{};
  int _activeIndex = 0;
  VideoPlayerController? _videoController;
  String _currentVideoUrl = '';
  String? _pendingVideoUrl;
  bool _pendingAutoplay = false;
  bool _isVideoLoading = false;
  int _videoRequestId = 0;
  bool _appliedSharedTarget = false;
  String? _lastTrackedAdminVideoId;
  String? _lastTrackedContestId;
  Map<String, int> _watchedAdminVideos = const <String, int>{};

  @override
  void initState() {
    super.initState();
    _feedStopHandlers.add(_clearActiveVideo);
    _loadWatchedAdminVideos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant _HomeFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _feedStopHandlers.remove(_clearActiveVideo);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _clearActiveVideo();
  }

  @override
  void didPopNext() {
    unlockFeedPlayback();
    _handleVisibilityChange();
  }

  Future<void> _handleVisibilityChange() async {
    if (!widget.isVisible) {
      await _clearActiveVideo();
      return;
    }
    unlockFeedPlayback();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActiveVideo(String url, {bool autoplay = true}) async {
    if (url.isEmpty) return;
    if (url == _currentVideoUrl &&
        _videoController == null &&
        _isVideoLoading) {
      return;
    }
    final requestId = ++_videoRequestId;
    if (mounted) {
      setState(() => _isVideoLoading = true);
    }
    if (url == _currentVideoUrl && _videoController != null) {
      final controller = _videoController!;
      await controller.setVolume(1);
      if (autoplay) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (mounted && requestId == _videoRequestId) {
        setState(() => _isVideoLoading = false);
      }
      return;
    }

    final previous = _videoController;
    _videoController = null;
    _currentVideoUrl = url;
    await previous?.pause();
    await previous?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      controller.addListener(() {
        if (!mounted ||
            _currentVideoUrl != url ||
            controller != _videoController) {
          return;
        }
        setState(() {});
      });
      if (requestId != _videoRequestId || !mounted) {
        await controller.pause();
        await controller.dispose();
        return;
      }
      if (mounted) {
        setState(() {
          _videoController = controller;
        });
      } else {
        _videoController = controller;
      }
      if (autoplay) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _currentVideoUrl = '';
          _isVideoLoading = false;
          _failedAdminVideoUrls.add(url);
        });
      } else {
        _currentVideoUrl = '';
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isVideoLoading = false;
    });
  }

  Future<void> _clearActiveVideo() async {
    if (_currentVideoUrl.isEmpty && _videoController == null) return;
    _videoRequestId++;
    _currentVideoUrl = '';
    _pendingVideoUrl = null;
    _pendingAutoplay = false;
    final controller = _videoController;
    _videoController = null;
    try {
      await controller?.setVolume(0);
    } catch (_) {}
    await controller?.pause();
    await controller?.dispose();
    if (mounted) {
      setState(() => _isVideoLoading = false);
    }
  }

  void _scheduleActiveVideoSync(_FeedItem item, {required bool autoplay}) {
    if (_feedPlaybackLocked) return;
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
      if (url == _currentVideoUrl &&
          _videoController == null &&
          _isVideoLoading) {
        return;
      }
      if (url == _currentVideoUrl &&
          _videoController != null &&
          _videoController!.value.isInitialized) {
        return;
      }
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

  Future<void> _trackFeedVideoView(_FeedItem item) async {
    if (item.isAdminVideo) {
      if (item.adminVideoId.isEmpty) return;
      if (_lastTrackedAdminVideoId == item.adminVideoId) return;
      _lastTrackedAdminVideoId = item.adminVideoId;
      await _markAdminVideoWatched(item.adminVideoId);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        await AuthService().incrementAdminVideoView(item.adminVideoId);
      } catch (_) {}
      return;
    }
    if (item.isContest) {
      if (item.contestId.isEmpty) return;
      if (_lastTrackedContestId == item.contestId) return;
      _lastTrackedContestId = item.contestId;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        await AuthService().incrementContestView(item.contestId);
      } catch (_) {}
    }
  }

  Future<void> _loadWatchedAdminVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_watchedAdminVideosPrefsKey) ?? <String>[];
    final watched = <String, int>{};
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      final millis = int.tryParse(parts[1]);
      if (parts[0].isEmpty || millis == null) continue;
      watched[parts[0]] = millis;
    }
    if (!mounted) {
      _watchedAdminVideos = watched;
      return;
    }
    setState(() {
      _watchedAdminVideos = watched;
    });
  }

  Future<void> _markAdminVideoWatched(String adminVideoId) async {
    if (adminVideoId.isEmpty || _watchedAdminVideos.containsKey(adminVideoId)) {
      return;
    }
    final updated = Map<String, int>.from(_watchedAdminVideos)
      ..[adminVideoId] = DateTime.now().millisecondsSinceEpoch;
    final entries = updated.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final trimmedEntries = entries.take(200).toList();
    final trimmed = <String, int>{
      for (final entry in trimmedEntries) entry.key: entry.value,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _watchedAdminVideosPrefsKey,
      trimmedEntries.map((e) => '${e.key}|${e.value}').toList(),
    );
    if (!mounted) {
      _watchedAdminVideos = trimmed;
      return;
    }
    setState(() {
      _watchedAdminVideos = trimmed;
    });
  }

  @override
  Widget build(BuildContext context) {
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

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('contests')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, contestsSnapshot) {
                if (contestsSnapshot.hasError) {
                  return Center(
                    child: Text(
                      context.tr('Unable to load contests.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                if (!contestsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final newsDocs = newsSnapshot.data!.docs;
                final adminVideoDocs = adminVideosSnapshot.data!.docs.where((
                  doc,
                ) {
                  final data = doc.data();
                  final isVisible = data['isVisibleOnFeed'];
                  if (isVisible is bool) return isVisible;
                  return true;
                }).toList();
                final contestDocs = contestsSnapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final contestType = (data['contestType'] ?? 'video_contest')
                      .toString();
                  final status = (data['status'] ?? '').toString();
                  final videoUrl = (data['contestVideoUrl'] ?? '').toString();
                  if (videoUrl.isEmpty) return false;
                  if (contestType == 'sponsor_contest') {
                    return status == 'live';
                  }
                  return true;
                }).toList();
                final feedItems = _buildFeedItems(
                  newsDocs,
                  adminVideoDocs,
                  contestDocs,
                );

                if (feedItems.isEmpty) {
                  return Center(
                    child: Text(
                      context.tr('No updates available right now.'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                if (!_appliedSharedTarget &&
                    widget.sharedAdminVideoId != null &&
                    widget.sharedAdminVideoId!.isNotEmpty) {
                  final targetIndex = feedItems.indexWhere(
                    (item) => item.adminVideoId == widget.sharedAdminVideoId,
                  );
                  if (targetIndex >= 0) {
                    _appliedSharedTarget = true;
                    _activeIndex = targetIndex;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      if (!mounted || !_pageController.hasClients) return;
                      _pageController.jumpToPage(targetIndex);
                      if (widget.isVisible) {
                        await _setActiveVideo(
                          feedItems[targetIndex].videoUrl,
                          autoplay: true,
                        );
                      }
                    });
                  }
                }

                final safeIndex = _activeIndex.clamp(0, feedItems.length - 1);
                final activeItem = feedItems[safeIndex];
                if (widget.isVisible) {
                  _scheduleActiveVideoSync(activeItem, autoplay: true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _trackFeedVideoView(activeItem);
                  });
                }

                return PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  itemCount: feedItems.length,
                  onPageChanged: (i) async {
                    setState(() => _activeIndex = i);
                    if (!widget.isVisible || _feedPlaybackLocked) return;
                    final item = feedItems[i];
                    if (item.hasVideo && item.videoUrl.isNotEmpty) {
                      await _setActiveVideo(item.videoUrl, autoplay: true);
                    } else {
                      await _clearActiveVideo();
                    }
                  },
                  itemBuilder: (context, index) {
                    final item = feedItems[index];
                    if (item.isNews) {
                      return _NewsFeedCard(item: item);
                    }
                    final isActive = index == safeIndex;
                    final isShowingActiveVideo =
                        isActive &&
                        _videoController != null &&
                        _videoController!.value.isInitialized &&
                        _currentVideoUrl == item.videoUrl;
                    final shouldShowLoading =
                        isActive &&
                        item.hasVideo &&
                        (_isVideoLoading || !isShowingActiveVideo);
                    final isPlaying =
                        isShowingActiveVideo &&
                        _videoController!.value.isPlaying;
                    if (item.isContest) {
                      return _ContestFeedCard(
                        item: item.toContestFeedItem(),
                        controller: isShowingActiveVideo
                            ? _videoController
                            : null,
                        isShowingActiveVideo: isShowingActiveVideo,
                        isPlaying: isPlaying,
                        isLoading: shouldShowLoading,
                        onTapVideo: isShowingActiveVideo
                            ? _togglePlayback
                            : null,
                      );
                    }
                    return _AdminVideoFeedCard(
                      item: item,
                      isShowingActiveVideo: isShowingActiveVideo,
                      isPlaying: isPlaying,
                      isLoading: shouldShowLoading,
                      controller: isShowingActiveVideo
                          ? _videoController
                          : null,
                      onTapVideo: isShowingActiveVideo ? _togglePlayback : null,
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> newsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> adminVideoDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> contestDocs,
  ) {
    final newsItems = newsDocs.map(_FeedItem.fromNews).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final adminVideoItems = adminVideoDocs
        .where((doc) {
          final videoUrl = (doc.data()['videoUrl'] ?? '').toString().trim();
          return videoUrl.isNotEmpty &&
              !_failedAdminVideoUrls.contains(videoUrl);
        })
        .map(_FeedItem.fromAdminVideo)
        .toList();

    final contestItems = contestDocs
        .map(_FeedItem.fromContest)
        .where((item) => !_failedAdminVideoUrls.contains(item.videoUrl))
        .toList();

    final videoItems = <_FeedItem>[...adminVideoItems, ...contestItems]
      ..sort((a, b) {
        final aOrder = a.displayOrder;
        final bOrder = b.displayOrder;
        if (aOrder != null && bOrder != null) {
          return aOrder.compareTo(bOrder);
        }
        if (aOrder != null) return -1;
        if (bOrder != null) return 1;
        if (a.isAdminVideo && b.isAdminVideo) {
          final aWatched = _watchedAdminVideos.containsKey(a.adminVideoId);
          final bWatched = _watchedAdminVideos.containsKey(b.adminVideoId);
          if (aWatched != bWatched) {
            return aWatched ? 1 : -1;
          }
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return <_FeedItem>[...videoItems, ...newsItems];
  }
}

class _PublicContestsTab extends StatefulWidget {
  const _PublicContestsTab({required this.isVisible, this.sharedContestId});

  final bool isVisible;
  final String? sharedContestId;

  @override
  State<_PublicContestsTab> createState() => _PublicContestsTabState();
}

class _PublicContestsTabState extends State<_PublicContestsTab>
    with RouteAware {
  final _pageController = PageController();
  int _activeIndex = 0;
  VideoPlayerController? _videoController;
  String _currentVideoUrl = '';
  String? _pendingVideoUrl;
  bool _isVideoLoading = false;
  int _videoRequestId = 0;
  bool _appliedSharedTarget = false;
  String? _lastTrackedContestId;

  @override
  void initState() {
    super.initState();
    _feedStopHandlers.add(_clearActiveVideo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant _PublicContestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _feedStopHandlers.remove(_clearActiveVideo);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _clearActiveVideo();
  }

  @override
  void didPopNext() {
    unlockFeedPlayback();
    _handleVisibilityChange();
  }

  Future<void> _handleVisibilityChange() async {
    if (!widget.isVisible) {
      await _clearActiveVideo();
      return;
    }
    unlockFeedPlayback();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActiveVideo(String url) async {
    if (url.isEmpty) return;
    if (url == _currentVideoUrl &&
        _videoController == null &&
        _isVideoLoading) {
      return;
    }
    final requestId = ++_videoRequestId;
    if (mounted) {
      setState(() => _isVideoLoading = true);
    }
    if (url == _currentVideoUrl && _videoController != null) {
      final controller = _videoController!;
      await controller.setVolume(1);
      await controller.play();
      if (mounted && requestId == _videoRequestId) {
        setState(() => _isVideoLoading = false);
      }
      return;
    }

    final previous = _videoController;
    _videoController = null;
    _currentVideoUrl = url;
    await previous?.pause();
    await previous?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      controller.addListener(() {
        if (!mounted ||
            _currentVideoUrl != url ||
            controller != _videoController) {
          return;
        }
        setState(() {});
      });
      if (requestId != _videoRequestId || !mounted) {
        await controller.pause();
        await controller.dispose();
        return;
      }
      if (mounted) {
        setState(() {
          _videoController = controller;
        });
      } else {
        _videoController = controller;
      }
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _currentVideoUrl = '';
          _isVideoLoading = false;
        });
      } else {
        _currentVideoUrl = '';
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _isVideoLoading = false;
    });
  }

  Future<void> _clearActiveVideo() async {
    _videoRequestId++;
    _currentVideoUrl = '';
    _pendingVideoUrl = null;
    final controller = _videoController;
    _videoController = null;
    try {
      await controller?.setVolume(0);
    } catch (_) {}
    await controller?.pause();
    await controller?.dispose();
    if (mounted) {
      setState(() => _isVideoLoading = false);
    }
  }

  void _scheduleActiveVideoSync(_ContestFeedItem item) {
    if (_feedPlaybackLocked) return;
    final desiredUrl = item.videoUrl;
    if (_pendingVideoUrl == desiredUrl) return;
    _pendingVideoUrl = desiredUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final url = _pendingVideoUrl ?? '';
      _pendingVideoUrl = null;
      if (url.isEmpty) {
        await _clearActiveVideo();
        return;
      }
      if (url == _currentVideoUrl &&
          _videoController == null &&
          _isVideoLoading) {
        return;
      }
      if (url == _currentVideoUrl &&
          _videoController != null &&
          _videoController!.value.isInitialized) {
        return;
      }
      await _setActiveVideo(url);
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

  Future<void> _trackContestView(_ContestFeedItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_lastTrackedContestId == item.id) return;
    _lastTrackedContestId = item.id;
    try {
      await AuthService().incrementContestView(item.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final contestType = (data['contestType'] ?? 'video_contest')
              .toString();
          final status = (data['status'] ?? '').toString();
          final videoUrl = (data['contestVideoUrl'] ?? '').toString();
          if (videoUrl.isEmpty) return false;
          if (contestType == 'sponsor_contest') {
            return status == 'live';
          }
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              context.tr('No contests available right now.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final items = docs.map(_ContestFeedItem.fromDoc).toList();

        if (!_appliedSharedTarget &&
            widget.sharedContestId != null &&
            widget.sharedContestId!.isNotEmpty) {
          final targetIndex = items.indexWhere(
            (item) => item.id == widget.sharedContestId,
          );
          if (targetIndex >= 0) {
            _appliedSharedTarget = true;
            _activeIndex = targetIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted || !_pageController.hasClients) return;
              _pageController.jumpToPage(targetIndex);
              if (widget.isVisible) {
                await _setActiveVideo(items[targetIndex].videoUrl);
              }
            });
          }
        }

        final safeIndex = _activeIndex.clamp(0, items.length - 1);
        final activeItem = items[safeIndex];
        if (widget.isVisible) {
          _scheduleActiveVideoSync(activeItem);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _trackContestView(activeItem);
          });
        }

        return PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: items.length,
          onPageChanged: (index) async {
            setState(() => _activeIndex = index);
            if (!widget.isVisible || _feedPlaybackLocked) return;
            await _setActiveVideo(items[index].videoUrl);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final isActive = index == safeIndex;
            final isShowingActiveVideo =
                isActive &&
                _videoController != null &&
                _videoController!.value.isInitialized &&
                _currentVideoUrl == item.videoUrl;
            final shouldShowLoading =
                isActive && (_isVideoLoading || !isShowingActiveVideo);
            final isPlaying =
                isShowingActiveVideo && _videoController!.value.isPlaying;
            return _ContestFeedCard(
              item: item,
              controller: isShowingActiveVideo ? _videoController : null,
              isShowingActiveVideo: isShowingActiveVideo,
              isPlaying: isPlaying,
              isLoading: shouldShowLoading,
              onTapVideo: isShowingActiveVideo ? _togglePlayback : null,
            );
          },
        );
      },
    );
  }
}

class _ContestFeedItem {
  const _ContestFeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.logoUrl,
    required this.contestType,
    required this.sponsorId,
    required this.winnerPrize,
    required this.data,
  });

  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String logoUrl;
  final String contestType;
  final String sponsorId;
  final double winnerPrize;
  final Map<String, dynamic> data;

  factory _ContestFeedItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ContestFeedItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      videoUrl: (data['contestVideoUrl'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? '').toString(),
      contestType: (data['contestType'] ?? 'video_contest').toString(),
      sponsorId: (data['sponsorId'] ?? '').toString(),
      winnerPrize: ((data['winnerPrize'] ?? 100) as num).toDouble(),
      data: Map<String, dynamic>.from(data),
    );
  }
}

class _ContestFeedCard extends StatelessWidget {
  const _ContestFeedCard({
    required this.item,
    required this.controller,
    required this.isShowingActiveVideo,
    required this.isPlaying,
    required this.isLoading,
    this.onTapVideo,
  });

  final _ContestFeedItem item;
  final VideoPlayerController? controller;
  final bool isShowingActiveVideo;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTapVideo;

  Future<void> _requireAuth(BuildContext context) async {
    await stopAllFeedPlayback();
    var navigated = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
    if (!navigated) {
      unlockFeedPlayback();
    }
  }

  void _openContest(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireAuth(context);
      return;
    }
    stopAllFeedPlayback().then((_) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ContestDetailScreen(contestId: item.id, data: item.data),
        ),
      );
    });
  }

  Future<void> _openParticipantVideos(BuildContext context) async {
    await stopAllFeedPlayback();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContestParticipantVideosSheet(
        contestId: item.id,
        contestTitle: item.title,
      ),
    );
    unlockFeedPlayback();
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isJoinOpen({
    required DateTime now,
    DateTime? submissionStart,
    DateTime? submissionEnd,
    DateTime? votingStart,
    DateTime? votingEnd,
  }) {
    final uploadStarted =
        submissionStart == null || !now.isBefore(submissionStart);
    final uploadEnded = submissionEnd != null && now.isAfter(submissionEnd);
    final votingStarted = votingStart != null && !now.isBefore(votingStart);
    final contestClosed = votingEnd != null && now.isAfter(votingEnd);

    if (contestClosed) return false;
    if (!uploadStarted) return false;
    if (uploadEnded) return false;
    if (votingStarted) return false;
    return true;
  }

  bool _isVotingOpen({
    required DateTime now,
    DateTime? votingStart,
    DateTime? votingEnd,
  }) {
    if (votingStart == null) return false;
    final started = !now.isBefore(votingStart);
    final ended = votingEnd != null && now.isAfter(votingEnd);
    return started && !ended;
  }

  String _formatMetric(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    }
    return value.toString();
  }

  Widget _buildJoinedMetricButton(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('contests')
          .doc(item.id)
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        final joinedCount = snapshot.data?.docs.length ?? 0;
        return _FeedMetricButton(
          icon: Icons.groups_2_outlined,
          value: _formatMetric(joinedCount),
          label: context.tr('Joined'),
          onTap: () => _openParticipantVideos(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final submissionStart = _readDate(item.data['submissionStart']);
    final submissionEnd = _readDate(
      item.data['submissionEnd'] ?? item.data['endDate'],
    );
    final votingStart = _readDate(item.data['votingStart']);
    final votingEnd = _readDate(item.data['votingEnd']);
    final canJoin = _isJoinOpen(
      now: now,
      submissionStart: submissionStart,
      submissionEnd: submissionEnd,
      votingStart: votingStart,
      votingEnd: votingEnd,
    );
    final canVote = _isVotingOpen(
      now: now,
      votingStart: votingStart,
      votingEnd: votingEnd,
    );
    final uploadStarted =
        submissionStart == null || !now.isBefore(submissionStart);
    final contestClosed = votingEnd != null && now.isAfter(votingEnd);
    final ctaEnabled = canJoin || canVote;
    final ctaTitle = canJoin
        ? context.tr('Join Contest')
        : canVote
        ? context.tr('Open Voting')
        : !uploadStarted
        ? context.tr('Coming Soon')
        : context.tr('Contest Closed');
    final ctaSubtitle = canJoin
        ? '${context.tr('Show your talent and compete to win')} \$${item.winnerPrize.toStringAsFixed(0)}!'
        : canVote
        ? context.tr('Voting is now open. Review entries and cast your vote.')
        : contestClosed
        ? context.tr('This contest is closed and voting has ended.')
        : context.tr('Contest submission will open soon.');
    final viewCount =
        ((item.data['viewCount'] ?? item.data['views'] ?? 0) as num).toInt();
    final shareCount = ((item.data['shareCount'] ?? 0) as num).toInt();
    return GestureDetector(
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
          else if (isLoading || isShowingActiveVideo)
            Container(
              color: AppColors.card,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.hotPink,
                  strokeWidth: 4.6,
                ),
              ),
            )
          else
            Container(color: AppColors.card),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.hotPink,
                strokeWidth: 4.6,
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD0100A1E)],
                stops: [0.42, 1],
              ),
            ),
          ),
          const Positioned(right: 16, top: 18, child: _FeedLogoBadge()),
          if (isShowingActiveVideo)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (isPlaying || isLoading) ? 0 : 1,
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
                      color: AppColors.hotPink,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 14,
            top: 180,
            child: Column(
              children: [
                _FeedMetricButton(
                  icon: Icons.visibility_outlined,
                  value: _formatMetric(viewCount),
                  label: context.tr('Views'),
                ),
                const SizedBox(height: 14),
                _FeedMetricButton(
                  icon: Icons.share_outlined,
                  value: _formatMetric(shareCount),
                  label: context.tr('Shares'),
                  onTap: () async {
                    if (FirebaseAuth.instance.currentUser == null) {
                      await _requireAuth(context);
                      return;
                    }
                    final link = _contestShareLink(item.id);
                    final text =
                        '${item.title}\n${item.description}\n${context.tr('Winner Prize')}: \$${item.winnerPrize.toStringAsFixed(0)}\n$link';
                    try {
                      await AuthService().incrementContestShare(item.id);
                    } catch (_) {}
                    await Share.share(text, subject: item.title);
                  },
                ),
                const SizedBox(height: 14),
                _buildJoinedMetricButton(context),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 102,
            child: _FeedActionRail(
              children: [
                _FeedStatTile(
                  icon: Icons.emoji_events_rounded,
                  title: context.tr('Prize'),
                  value: '\$${item.winnerPrize.toStringAsFixed(0)}',
                  accent: const Color(0xFFF5C14B),
                ),
                if (submissionEnd != null)
                  _FeedCountdownTile(
                    icon: Icons.file_upload_outlined,
                    title: context.tr('Upload Ends'),
                    target: submissionEnd,
                    accent: AppColors.hotPink,
                  ),
                if (votingStart != null)
                  _FeedCountdownTile(
                    icon: Icons.how_to_vote_outlined,
                    title: context.tr('Voting Starts'),
                    target: votingStart,
                    accent: const Color(0xFF54C7FF),
                  ),
                if (votingEnd != null)
                  _FeedCountdownTile(
                    icon: Icons.emoji_events_outlined,
                    title: context.tr('Voting Ends'),
                    target: votingEnd,
                    accent: const Color(0xFF9BFF5C),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 96,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.logoUrl.isNotEmpty
                          ? Image.network(
                              item.logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.emoji_events,
                                color: AppColors.hotPink,
                              ),
                            )
                          : const Icon(
                              Icons.emoji_events,
                              color: AppColors.hotPink,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: ctaEnabled ? () => _openContest(context) : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: ctaEnabled
                            ? const [Color(0xFFF52C79), Color(0xFF7C38F5)]
                            : const [Color(0xFF5A5367), Color(0xFF383447)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (ctaEnabled
                                      ? AppColors.hotPink
                                      : const Color(0xFF5A5367))
                                  .withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ctaTitle.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ctaSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                      ],
                    ),
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

class _FeedItem {
  const _FeedItem({
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.imageUrl = '',
    this.videoUrl = '',
    this.adminName = '',
    this.adminVideoId = '',
    this.contestId = '',
    this.logoUrl = '',
    this.winnerPrize = 0,
    this.contestData = const <String, dynamic>{},
    this.displayOrder,
    this.viewCount = 0,
    this.shareCount = 0,
  });

  final String type;
  final String title;
  final String description;
  final DateTime createdAt;
  final String imageUrl;
  final String videoUrl;
  final String adminName;
  final String adminVideoId;
  final String contestId;
  final String logoUrl;
  final double winnerPrize;
  final Map<String, dynamic> contestData;
  final int? displayOrder;
  final int viewCount;
  final int shareCount;

  bool get isNews => type == 'news';
  bool get isAdminVideo => type == 'admin_video';
  bool get isContest => type == 'contest';
  bool get hasVideo => isAdminVideo || isContest;

  factory _FeedItem.fromNews(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _FeedItem(
      type: 'news',
      title: (data['title'] ?? '').toString(),
      description: ((data['details'] ?? data['body']) ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      adminName: (data['adminName'] ?? 'Admin').toString(),
      adminVideoId: doc.id,
      displayOrder: (data['displayOrder'] as num?)?.toInt(),
      viewCount: ((data['views'] ?? data['viewCount'] ?? 0) as num).toInt(),
      shareCount: ((data['shareCount'] ?? 0) as num).toInt(),
    );
  }

  factory _FeedItem.fromContest(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _FeedItem(
      type: 'contest',
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      videoUrl: (data['contestVideoUrl'] ?? '').toString(),
      contestId: doc.id,
      logoUrl: (data['logoUrl'] ?? '').toString(),
      winnerPrize: ((data['winnerPrize'] ?? 100) as num).toDouble(),
      contestData: Map<String, dynamic>.from(data),
      viewCount: ((data['viewCount'] ?? data['views'] ?? 0) as num).toInt(),
      shareCount: ((data['shareCount'] ?? 0) as num).toInt(),
    );
  }

  _ContestFeedItem toContestFeedItem() {
    return _ContestFeedItem(
      id: contestId,
      title: title,
      description: description,
      videoUrl: videoUrl,
      logoUrl: logoUrl,
      contestType: (contestData['contestType'] ?? 'video_contest').toString(),
      sponsorId: (contestData['sponsorId'] ?? '').toString(),
      winnerPrize: winnerPrize,
      data: contestData,
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
    required this.isLoading,
    required this.controller,
    this.onTapVideo,
  });

  final _FeedItem item;
  final bool isShowingActiveVideo;
  final bool isPlaying;
  final bool isLoading;
  final VideoPlayerController? controller;
  final VoidCallback? onTapVideo;

  Future<void> _requireAuth(BuildContext context) async {
    await stopAllFeedPlayback();
    var navigated = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
    if (!navigated) {
      unlockFeedPlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    String formatMetric(int value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
      }
      if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
      }
      return value.toString();
    }

    return GestureDetector(
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
          else if (isLoading || isShowingActiveVideo)
            Container(
              color: AppColors.card,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.hotPink,
                  strokeWidth: 4.6,
                ),
              ),
            )
          else
            Container(color: AppColors.card),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.hotPink,
                strokeWidth: 4.6,
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD0100A1E)],
                stops: [0.42, 1],
              ),
            ),
          ),
          const Positioned(right: 16, top: 18, child: _FeedLogoBadge()),
          if (isShowingActiveVideo)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (isPlaying || isLoading) ? 0 : 1,
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
                      color: AppColors.hotPink,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 14,
            top: 210,
            child: _FeedActionRail(
              children: [
                _FeedMetricButton(
                  icon: Icons.visibility_outlined,
                  value: formatMetric(item.viewCount),
                  label: context.tr('Views'),
                ),
                const SizedBox(height: 14),
                _FeedMetricButton(
                  icon: Icons.share_outlined,
                  value: formatMetric(item.shareCount),
                  label: context.tr('Shares'),
                  onTap: () async {
                    if (FirebaseAuth.instance.currentUser == null) {
                      await _requireAuth(context);
                      return;
                    }
                    final link = _feedVideoShareLink(item.adminVideoId);
                    final text = '${item.adminName}\nClick Kick\n$link';
                    try {
                      await AuthService().incrementAdminVideoShare(
                        item.adminVideoId,
                      );
                    } catch (_) {}
                    await Share.share(text, subject: item.adminName);
                  },
                ),
                const SizedBox(height: 14),
                _FeedActionButton(
                  icon: Icons.flag_outlined,
                  label: context.tr('Report'),
                  onTap: () => showReportVideoDialog(
                    context: context,
                    videoType: 'admin_video',
                    adminVideoId: item.adminVideoId,
                    contestTitle: item.adminName,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 82,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  maxLines: 3,
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
    );
  }
}

class _FeedActionRail extends StatelessWidget {
  const _FeedActionRail({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: compact ? 21 : 24),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            width: 58,
            child: Text(
              label,
              maxLines: compact ? 3 : 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedMetricButton extends StatelessWidget {
  const _FeedMetricButton({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hotPink.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.hotPink.withValues(alpha: 0.22),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.hotPink, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 70,
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: content,
    );
  }
}

class _FeedLogoBadge extends StatelessWidget {
  const _FeedLogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.hotPink.withValues(alpha: 0.16),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}

class _FeedBrandBadge extends StatelessWidget {
  const _FeedBrandBadge({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.emoji_events_rounded,
          color: AppColors.hotPink,
          size: 26,
        ),
      ),
    );
  }
}

class _FeedStatTile extends StatelessWidget {
  const _FeedStatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCountdownTile extends StatelessWidget {
  const _FeedCountdownTile({
    required this.icon,
    required this.title,
    required this.target,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final DateTime target;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final remaining = target.difference(now);
        final isDone = remaining.isNegative;
        final days = isDone ? 0 : remaining.inDays;
        final hours = isDone ? 0 : remaining.inHours.remainder(24);
        final minutes = isDone ? 0 : remaining.inMinutes.remainder(60);
        final seconds = isDone ? 0 : remaining.inSeconds.remainder(60);

        String part(int value) => value.toString().padLeft(2, '0');

        return Container(
          width: 70,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(height: 4),
              Text(
                title.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${part(days)}:${part(hours)}:${part(minutes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (isDone) ...[
                const SizedBox(height: 3),
                Text(
                  context.tr('Closed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 2),
                Text(
                  part(seconds),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('D : H : M : S'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.95),
                    fontSize: 7.8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FeedInfoBadge extends StatelessWidget {
  const _FeedInfoBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 58,
          child: Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 58,
          child: Text(
            subtitle,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContestParticipantVideosSheet extends StatelessWidget {
  const _ContestParticipantVideosSheet({
    required this.contestId,
    required this.contestTitle,
  });

  final String contestId;
  final String contestTitle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.deepSpace,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Participant Videos'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contestTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('contests')
                      .doc(contestId)
                      .collection('submissions')
                      .where('status', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs.toList()
                      ..sort((a, b) {
                        final av = ((a.data()['voteCount'] ?? 0) as num)
                            .toInt();
                        final bv = ((b.data()['voteCount'] ?? 0) as num)
                            .toInt();
                        return bv.compareTo(av);
                      });
                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.tr('No participant videos yet.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final title =
                            (data['title'] ??
                                    data['description'] ??
                                    context.tr('Contest Video'))
                                .toString();
                        final userName =
                            (data['userName'] ??
                                    data['participantName'] ??
                                    data['displayName'] ??
                                    context.tr('Participant'))
                                .toString();
                        final videoUrl = (data['videoUrl'] ?? '').toString();
                        final thumbUrl = (data['thumbnailUrl'] ?? '')
                            .toString();
                        final votes = ((data['voteCount'] ?? 0) as num).toInt();
                        final shares = ((data['shareCount'] ?? 0) as num)
                            .toInt();

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: videoUrl.isEmpty
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _ContestParticipantReelsScreen(
                                        contestTitle: contestTitle,
                                        initialIndex: index,
                                        videos: docs
                                            .map(
                                              (
                                                entry,
                                              ) => _ContestParticipantVideo(
                                                id: entry.id,
                                                title:
                                                    (entry.data()['title'] ??
                                                            entry
                                                                .data()['description'] ??
                                                            context.tr(
                                                              'Contest Video',
                                                            ))
                                                        .toString(),
                                                participantName:
                                                    (entry.data()['userName'] ??
                                                            entry
                                                                .data()['participantName'] ??
                                                            entry
                                                                .data()['displayName'] ??
                                                            context.tr(
                                                              'Participant',
                                                            ))
                                                        .toString(),
                                                videoUrl:
                                                    (entry.data()['videoUrl'] ??
                                                            '')
                                                        .toString(),
                                                votes:
                                                    ((entry.data()['voteCount'] ??
                                                                0)
                                                            as num)
                                                        .toInt(),
                                                shares:
                                                    ((entry.data()['shareCount'] ??
                                                                0)
                                                            as num)
                                                        .toInt(),
                                              ),
                                            )
                                            .where(
                                              (entry) =>
                                                  entry.videoUrl.isNotEmpty,
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  );
                                },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 88,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (thumbUrl.isNotEmpty)
                                        Image.network(
                                          thumbUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      Container(
                                        color: thumbUrl.isEmpty
                                            ? Colors.black.withValues(
                                                alpha: 0.16,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.16,
                                              ),
                                      ),
                                      const Center(
                                        child: Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                      ),
                                    ],
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
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.how_to_vote_rounded,
                                            color: AppColors.hotPink,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$votes ${context.tr('votes')}',
                                            style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          const Icon(
                                            Icons.share_outlined,
                                            color: AppColors.hotPink,
                                            size: 17,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$shares',
                                            style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.hotPink
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: AppColors.hotPink
                                                    .withValues(alpha: 0.32),
                                              ),
                                            ),
                                            child: Text(
                                              context.tr('Watch'),
                                              style: const TextStyle(
                                                color: AppColors.hotPink,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
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
        );
      },
    );
  }
}

class _NewsFeedCardState extends State<_NewsFeedCard> {
  bool _expanded = false;

  Future<void> _requireAuth(BuildContext context) async {
    await stopAllFeedPlayback();
    var navigated = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              navigated = true;
              await stopAllFeedPlayback();
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
    if (!navigated) {
      unlockFeedPlayback();
    }
  }

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
                right: 14,
                bottom: 138,
                child: _FeedActionRail(
                  children: [
                    _FeedActionButton(
                      icon: Icons.share_rounded,
                      label: context.tr('Share'),
                      onTap: () async {
                        if (FirebaseAuth.instance.currentUser == null) {
                          await _requireAuth(context);
                          return;
                        }
                        final text = '${item.title}\n${item.description}';
                        await Share.share(text, subject: item.title);
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 84,
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
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
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
                const Icon(
                  Icons.dashboard_customize,
                  size: 44,
                  color: AppColors.hotPink,
                ),
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
  State<_ParticipantDashboardTab> createState() =>
      _ParticipantDashboardTabState();
}

class _ParticipantDashboardTabState extends State<_ParticipantDashboardTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _errorMessage;

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
            (data['contestId'] ?? doc.reference.parent.parent?.id ?? '')
                .toString();
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
      final contestDoc = await firestore
          .collection('contests')
          .doc(contestId)
          .get();
      if (!contestDoc.exists) continue;
      final votingEnd = (contestDoc.data()?['votingEnd'] as Timestamp?)
          ?.toDate();
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
          .where(
            (sub) =>
                ((sub.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
          )
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
        _errorMessage = context.tr(
          'Dashboard request timed out. Check internet and retry.',
        );
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
    if (context.isArabic &&
        (value == key || RegExp(r'^[A-Za-z]').hasMatch(value))) {
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
                    _errorMessage ??
                        context.tr('Unable to load dashboard data. Tap retry.'),
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

        final docs =
            List<Map<String, dynamic>>.from(
              snapshot.data ?? <Map<String, dynamic>>[],
            )..sort((a, b) {
              final at =
                  (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bt =
                  (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });
        final approved = docs
            .where((e) => (e['status'] ?? '') == 'approved')
            .length;
        final winners = docs.where((e) => e['isWinner'] == true).length;
        final authUser = FirebaseAuth.instance.currentUser;
        final fallbackName = docs.isNotEmpty
            ? ((docs.first['userName'] ??
                          docs.first['participantName'] ??
                          docs.first['displayName']) ??
                      '')
                  .toString()
            : '';
        final profileName = (authUser?.displayName?.trim().isNotEmpty ?? false)
            ? authUser!.displayName!.trim()
            : (fallbackName.isNotEmpty
                  ? fallbackName
                  : context.tr('Participant'));
        final profileEmail = (authUser?.email ?? '').trim();
        final profilePhotoUrl = (authUser?.photoURL ?? '').trim();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardSoft,
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profilePhotoUrl.isNotEmpty
                              ? Image.network(
                                  profilePhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.hotPink,
                                    size: 38,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.hotPink,
                                  size: 38,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profileName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (profileEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profileEmail,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _ProfileStatBlock(
                                value: docs.length.toString(),
                                label: _t(
                                  context,
                                  'Total Videos',
                                  'إجمالي الفيديوهات',
                                ),
                              ),
                            ),
                            Expanded(
                              child: _ProfileStatBlock(
                                value: approved.toString(),
                                label: _t(context, 'Approved', 'مقبول'),
                              ),
                            ),
                            Expanded(
                              child: _ProfileStatBlock(
                                value: winners.toString(),
                                label: _t(context, 'Winner', 'الفائز'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr('No videos found for selected filter.'),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = docs[index];
                      final status = (data['isWinner'] == true)
                          ? 'winner'
                          : (data['status'] ?? 'pending').toString();
                      final videoUrl = (data['videoUrl'] ?? '').toString();
                      final contestName =
                          (data['contestName'] ??
                                  data['contestTitle'] ??
                                  data['contestId'] ??
                                  '')
                              .toString();
                      final votes = ((data['voteCount'] ?? 0) as num).toInt();
                      final reason = (data['rejectionReason'] ?? '').toString();

                      Color badge = AppColors.sunset;
                      String badgeLabel = _t(
                        context,
                        'Pending',
                        'قيد الانتظار',
                      );
                      if (status == 'approved') {
                        badge = const Color(0xFF2DAF6F);
                        badgeLabel = _t(context, 'Approved', 'مقبول');
                      } else if (status == 'rejected') {
                        badge = const Color(0xFFC53D5D);
                        badgeLabel = _t(context, 'Rejected', 'مرفوض');
                      } else if (status == 'winner') {
                        badge = AppColors.hotPink;
                        badgeLabel = _t(context, 'Winner', 'الفائز');
                      }

                      return GestureDetector(
                        onTap: videoUrl.isEmpty
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _DashboardVideoPlayerScreen(
                                      videoUrl: videoUrl,
                                      title: contestName,
                                    ),
                                  ),
                                );
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.cardSoft,
                                        AppColors.card,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: AppColors.hotPink,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badge.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: badge,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contestName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.how_to_vote_rounded,
                                          color: AppColors.hotPink,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${_t(context, 'Votes', 'الأصوات')}: $votes',
                                            style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (status == 'rejected' &&
                                        reason.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        reason,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: docs.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileStatBlock extends StatelessWidget {
  const _ProfileStatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
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

class _DashboardVideoPlayerScreen extends StatefulWidget {
  const _DashboardVideoPlayerScreen({
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;

  @override
  State<_DashboardVideoPlayerScreen> createState() =>
      _DashboardVideoPlayerScreenState();
}

class _DashboardVideoPlayerScreenState
    extends State<_DashboardVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) async {
        if (!mounted) return;
        await _controller?.setLooping(true);
        await _controller?.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
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
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: controller != null && controller.value.isInitialized
                    ? GestureDetector(
                        onTap: () =>
                            setState(() => _showControls = !_showControls),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: _showControls ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.18),
                                child: Column(
                                  children: [
                                    const Spacer(),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _togglePlayback,
                                        child: Container(
                                          width: 78,
                                          height: 78,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.42,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            controller.value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 42,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          VideoProgressIndicator(
                                            controller,
                                            allowScrubbing: true,
                                            colors: const VideoProgressColors(
                                              playedColor: AppColors.hotPink,
                                              bufferedColor:
                                                  AppColors.textMuted,
                                              backgroundColor: AppColors.border,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                controller.value.isPlaying
                                                    ? context.tr('Pause')
                                                    : context.tr('Play'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                widget.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 12,
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
                            ),
                          ],
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestParticipantVideo {
  const _ContestParticipantVideo({
    required this.id,
    required this.title,
    required this.participantName,
    required this.videoUrl,
    required this.votes,
    required this.shares,
  });

  final String id;
  final String title;
  final String participantName;
  final String videoUrl;
  final int votes;
  final int shares;
}

class _ContestParticipantReelsScreen extends StatefulWidget {
  const _ContestParticipantReelsScreen({
    required this.contestTitle,
    required this.videos,
    this.initialIndex = 0,
  });

  final String contestTitle;
  final List<_ContestParticipantVideo> videos;
  final int initialIndex;

  @override
  State<_ContestParticipantReelsScreen> createState() =>
      _ContestParticipantReelsScreenState();
}

class _ContestParticipantReelsScreenState
    extends State<_ContestParticipantReelsScreen> {
  late final PageController _pageController;
  VideoPlayerController? _controller;
  int _currentIndex = 0;
  bool _showControls = true;

  _ContestParticipantVideo get _currentVideo => widget.videos[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadVideo(widget.videos[_currentIndex].videoUrl);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(String videoUrl) async {
    final old = _controller;
    final next = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    setState(() {
      _controller = null;
    });
    await old?.dispose();
    await next.initialize();
    await next.setLooping(true);
    await next.play();
    if (!mounted) {
      await next.dispose();
      return;
    }
    setState(() {
      _controller = next;
      _showControls = true;
    });
  }

  Future<void> _onPageChanged(int index) async {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    await _loadVideo(widget.videos[index].videoUrl);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
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
    final controller = _controller;
    final current = _currentVideo;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (index) => _onPageChanged(index),
            itemBuilder: (context, index) {
              final video = widget.videos[index];
              final isActive = index == _currentIndex;
              final activeController = isActive ? controller : null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (isActive &&
                      activeController != null &&
                      activeController.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: activeController.value.size.width,
                        height: activeController.value.size.height,
                        child: VideoPlayer(activeController),
                      ),
                    )
                  else
                    Container(color: AppColors.card),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD0100A1E)],
                        stops: [0.42, 1],
                      ),
                    ),
                  ),
                  if (isActive)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          setState(() => _showControls = !_showControls),
                    ),
                  const Positioned(right: 16, top: 22, child: _FeedLogoBadge()),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.contestTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentIndex + 1} / ${widget.videos.length}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 118,
                    child: _FeedActionRail(
                      children: [
                        _FeedMetricButton(
                          icon: Icons.how_to_vote_rounded,
                          value: current.votes.toString(),
                          label: context.tr('Votes'),
                        ),
                        _FeedMetricButton(
                          icon: Icons.share_outlined,
                          value: current.shares.toString(),
                          label: context.tr('Shares'),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 82,
                    bottom: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          video.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity:
                            _showControls &&
                                (activeController == null ||
                                    !activeController.value.isPlaying)
                            ? 1
                            : 0,
                        duration: const Duration(milliseconds: 180),
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
                              color: AppColors.hotPink,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (controller == null)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.hotPink,
                strokeWidth: 4.6,
              ),
            ),
          if (controller != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _togglePlayback,
              ),
            ),
        ],
      ),
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

class _PublicUserProfileTab extends StatelessWidget {
  const _PublicUserProfileTab({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final displayName =
            (data['displayName'] ?? user.displayName ?? context.tr('User'))
                .toString();
        final email = (data['email'] ?? user.email ?? '').toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.hotPink,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionTile(
              icon: Icons.person_outline,
              title: context.tr('Profile'),
              subtitle: context.tr(
                'Manage profile, language, and security in one place.',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PublicUserProfileUpdateScreen(user: user),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.support_agent_outlined,
              title: context.tr('Support'),
              subtitle: context.tr('Chat with support team.'),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatScreen(
                      threadId: user.uid,
                      title: context.tr('Support'),
                      subtitle: user.email,
                    ),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.privacy_tip_outlined,
              title: context.tr('Legal & Privacy'),
              subtitle: context.tr('Terms, guidelines, and privacy policy.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalCenterScreen()),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.delete_outline_rounded,
              title: context.tr('Delete Account'),
              subtitle: context.tr('Permanently remove your account.'),
              isDanger: true,
              onTap: () async {
                final confirmed = await showDeleteAccountDialog(context);
                if (confirmed != true) return;
                try {
                  await AuthService().deleteCurrentAccount();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('Account deleted successfully.'),
                      ),
                    ),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  final message = e.toString().contains('requires-recent-login')
                      ? context.tr(
                          'Please login again before deleting your account.',
                        )
                      : context.tr(
                          'Unable to delete account right now. Please try again.',
                        );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
            SettingsActionTile(
              icon: Icons.logout,
              title: context.tr('Logout'),
              subtitle: context.tr('Sign out from your account.'),
              isDanger: true,
              onTap: () async {
                await AuthService().signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              },
            ),
          ],
        );
      },
    );
  }
}

class _PublicUserProfileInfoScreen extends StatelessWidget {
  const _PublicUserProfileInfoScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ScreenHeader(title: context.tr('Profile Info')),
                    const SizedBox(height: 16),
                    _ReadOnlyInfoCard(
                      rows: [
                        _InfoRow(
                          context.tr('Full Name'),
                          (data['displayName'] ?? user.displayName ?? '')
                              .toString(),
                        ),
                        _InfoRow(
                          context.tr('Email'),
                          (data['email'] ?? user.email ?? '').toString(),
                        ),
                        _InfoRow(
                          context.tr('Phone number'),
                          (() {
                            final code = (data['phoneCountryCode'] ?? '')
                                .toString();
                            final phone = (data['phoneNumber'] ?? '')
                                .toString();
                            final direct = '$code $phone'.trim();
                            if (direct.isNotEmpty) return direct;
                            return (data['phoneE164'] ?? '').toString();
                          })(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicUserProfileUpdateScreen extends StatefulWidget {
  const _PublicUserProfileUpdateScreen({required this.user});

  final User user;

  @override
  State<_PublicUserProfileUpdateScreen> createState() =>
      _PublicUserProfileUpdateScreenState();
}

class _PublicUserProfileUpdateScreenState
    extends State<_PublicUserProfileUpdateScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _phoneCodeController = TextEditingController(
    text: '+1',
  );
  final TextEditingController _phoneNumberController = TextEditingController();
  String _phoneIso = 'US';
  bool _loading = true;
  bool _saving = false;
  Uint8List? _photoBytes;
  String _photoUrl = '';
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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
    _photoUrl = widget.user.photoURL ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    _nameController.text = (data['displayName'] ?? _nameController.text)
        .toString();
    _emailController.text = (data['email'] ?? _emailController.text).toString();
    _phoneCodeController.text = (data['phoneCountryCode'] ?? '+1').toString();
    _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    _phoneNumberController.text = (data['phoneNumber'] ?? '').toString();
    _photoUrl = (data['photoUrl'] ?? _photoUrl).toString();
    setState(() => _loading = false);
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

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final rawBytes = await file.readAsBytes();
    final compressed = await compute(_compressProfilePhotoBytes, rawBytes);
    if (!mounted) return;
    setState(() => _photoBytes = compressed);
  }

  Future<String> _uploadProfilePhoto(String uid) async {
    if (_photoBytes == null) return _photoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'profile_photos/$uid/profile.jpg',
    );
    await ref.putData(
      _photoBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim().toLowerCase();
      final willUpdateEmail =
          newEmail.isNotEmpty && newEmail != (user.email ?? '');
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      final willUpdatePassword =
          newPassword.isNotEmpty || confirmPassword.isNotEmpty;
      if (willUpdatePassword && newPassword != confirmPassword) {
        _show(
          context,
          context.tr('New password and confirm password do not match.'),
        );
        return;
      }
      if (willUpdateEmail || willUpdatePassword) {
        if (_currentPasswordController.text.trim().isEmpty) {
          _show(context, context.tr('Current password is required.'));
          return;
        }
        if (willUpdatePassword && newPassword.length < 6) {
          _show(
            context,
            context.tr('New password must be at least 6 characters.'),
          );
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: _currentPasswordController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
      }
      if (willUpdateEmail) {
        await user.verifyBeforeUpdateEmail(
          newEmail,
          AuthService.emailActionCodeSettings(),
        );
      }
      if (willUpdatePassword) {
        await user.updatePassword(newPassword);
      }
      final uploadedPhotoUrl = await _uploadProfilePhoto(user.uid);
      await user.updateDisplayName(newName);
      if (uploadedPhotoUrl.isNotEmpty) {
        await user.updatePhotoURL(uploadedPhotoUrl);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'email': (user.email ?? '').trim().toLowerCase(),
        'emailLower': (user.email ?? '').trim().toLowerCase(),
        'phoneCountryCode': _phoneCodeController.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumberController.text.trim(),
        'phoneE164':
            '${_phoneCodeController.text.trim()}${_phoneNumberController.text.trim()}',
        'photoUrl': uploadedPhotoUrl,
        if (willUpdateEmail) 'pendingEmail': newEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _photoUrl = uploadedPhotoUrl;
      _photoBytes = null;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _show(
        context,
        willUpdateEmail
            ? context.tr(
                'Verification email sent. Confirm it to complete email change.',
              )
            : context.tr('Profile updated.'),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, context.tr('Current password is incorrect.'));
      } else if (e.code == 'email-already-in-use') {
        _show(context, context.tr('This email is already in use.'));
      } else if (e.code == 'requires-recent-login') {
        _show(
          context,
          context.tr('Please login again before changing your email.'),
        );
      } else {
        _show(context, context.tr('Profile update failed (${e.code}).'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ScreenHeader(title: context.tr('Profile Update')),
                      const SizedBox(height: 16),
                      _FormCard(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.cardSoft,
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _photoBytes != null
                                            ? Image.memory(
                                                _photoBytes!,
                                                fit: BoxFit.cover,
                                              )
                                            : _photoUrl.isNotEmpty
                                            ? Image.network(
                                                _photoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.person_rounded,
                                                      color: AppColors.hotPink,
                                                      size: 42,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person_rounded,
                                                color: AppColors.hotPink,
                                                size: 42,
                                              ),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.hotPink,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.deepSpace,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr('Upload profile photo'),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: context.tr('Full Name'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: context.tr('Email'),
                              ),
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
                                            _phoneCodeController.text =
                                                '+${country.phoneCode}';
                                            _phoneIso = country.countryCode;
                                          });
                                        },
                                      );
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: context.tr('Country code'),
                                      ),
                                      child: Text(
                                        '$_phoneIso ${_phoneCodeController.text}',
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
                                    decoration: InputDecoration(
                                      labelText: context.tr('Phone number'),
                                    ),
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
                                    () => _obscureCurrentPassword =
                                        !_obscureCurrentPassword,
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
                                labelText: context.tr(
                                  'New Password (optional)',
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureNewPassword =
                                        !_obscureNewPassword,
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
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.language_outlined,
                                color: AppColors.textLight,
                              ),
                              title: Text(context.tr('Language')),
                              subtitle: Text(context.tr('Choose language')),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LanguageSelectionScreen(),
                                  ),
                                );
                              },
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
                                  _saving
                                      ? context.tr('Saving...')
                                      : context.tr('Update Profile'),
                                ),
                              ),
                            ),
                          ],
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

class _PublicUserPasswordScreen extends StatefulWidget {
  const _PublicUserPasswordScreen({required this.user});

  final User user;

  @override
  State<_PublicUserPasswordScreen> createState() =>
      _PublicUserPasswordScreenState();
}

class _PublicUserPasswordScreenState extends State<_PublicUserPasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _saving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    setState(() => _submitted = true);
    if (_currentPasswordController.text.trim().isEmpty) {
      _show(context, context.tr('Current password is required.'));
      return;
    }
    if (_newPasswordController.text.trim().isEmpty) {
      _show(context, context.tr('New password is required.'));
      return;
    }
    if (_newPasswordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _show(
        context,
        context.tr('New password and confirm password do not match.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());
      if (!mounted) return;
      _show(context, context.tr('Password updated successfully.'));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, context.tr('Current password is incorrect.'));
      } else if (e.code == 'weak-password') {
        _show(context, context.tr('New password is too weak.'));
      } else {
        _show(context, context.tr('Password update failed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordChangeLayout(
      title: context.tr('Change Password'),
      currentController: _currentPasswordController,
      newController: _newPasswordController,
      confirmController: _confirmPasswordController,
      currentObscure: _obscureCurrentPassword,
      newObscure: _obscureNewPassword,
      confirmObscure: _obscureConfirmPassword,
      onToggleCurrent: () =>
          setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
      onToggleNew: () =>
          setState(() => _obscureNewPassword = !_obscureNewPassword),
      onToggleConfirm: () =>
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      onSubmit: _changePassword,
      saving: _saving,
      currentError: _submitted && _currentPasswordController.text.trim().isEmpty
          ? context.tr('Current password is required.')
          : null,
      newError: _submitted
          ? (_newPasswordController.text.trim().isEmpty
                ? context.tr('New password is required.')
                : null)
          : null,
      confirmError: _submitted
          ? (_confirmPasswordController.text.trim().isEmpty
                ? context.tr('Confirm password is required.')
                : _newPasswordController.text.trim() !=
                      _confirmPasswordController.text.trim()
                ? context.tr('New password and confirm password do not match.')
                : null)
          : null,
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _ReadOnlyInfoCard extends StatelessWidget {
  const _ReadOnlyInfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.value.isEmpty ? '-' : row.value,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: SizedBox(
                width: 108,
                height: 84,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.card.withOpacity(0.96),
                    AppColors.cardSoft.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.hotPink, AppColors.magenta],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.hotPink.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('Sign In'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user == null
                        ? context.tr(
                            'Login to manage your profile, contests and much more.',
                          )
                        : (user.email ?? context.tr('Logged in user')),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (user == null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [AppColors.hotPink, AppColors.magenta],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.hotPink.withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            stopAllFeedPlayback().then((_) {
                              if (!context.mounted) return;
                              Navigator.pushNamed(context, '/login');
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: Text(
                            context.tr('Login'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          stopAllFeedPlayback().then((_) {
                            if (!context.mounted) return;
                            Navigator.pushNamed(context, '/register');
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.42),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          context.tr('Create Account'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Expanded(
                          child: _GuestBenefit(
                            icon: Icons.verified_user_outlined,
                            title: 'Secure',
                            subtitle: '100% Safe',
                          ),
                        ),
                        Expanded(
                          child: _GuestBenefit(
                            icon: Icons.emoji_events_outlined,
                            title: 'Contests',
                            subtitle: 'Join & Win',
                          ),
                        ),
                        Expanded(
                          child: _GuestBenefit(
                            icon: Icons.person_outline_rounded,
                            title: 'Personalized',
                            subtitle: 'Just for you',
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr('You are already signed in.'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestBenefit extends StatelessWidget {
  const _GuestBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.hotPink, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.color,
  });

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
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
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

class FeedVideoShareRouteScreen extends StatelessWidget {
  const FeedVideoShareRouteScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_videos')
          .doc(videoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.deepSpace),
            body: Center(child: Text(context.tr('Unable to load video.'))),
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
            body: Center(child: Text(context.tr('Video not found.'))),
          );
        }
        final adminName = (data['adminName'] ?? 'Click Kick').toString();
        final caption = (data['caption'] ?? '').toString();
        final videoUrl = (data['videoUrl'] ?? '').toString();

        return Scaffold(
          backgroundColor: AppColors.deepSpace,
          appBar: AppBar(
            backgroundColor: AppColors.deepSpace,
            title: Text(adminName),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoUrl.isNotEmpty)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _InlineVideoPlayer(videoUrl: videoUrl),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(context.tr('Video not found.')),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  adminName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    caption,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.videoUrl});

  final String videoUrl;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller?.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: Container(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

Uint8List _compressProfilePhotoBytes(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return input;

  img.Image processed = decoded;
  const maxDimension = 640;
  if (processed.width > maxDimension || processed.height > maxDimension) {
    processed = img.copyResize(
      processed,
      width: processed.width >= processed.height ? maxDimension : null,
      height: processed.height > processed.width ? maxDimension : null,
      interpolation: img.Interpolation.average,
    );
  }

  var quality = 85;
  Uint8List bytes = Uint8List.fromList(
    img.encodeJpg(processed, quality: quality),
  );
  while (bytes.lengthInBytes > 100 * 1024 && quality > 35) {
    quality -= 10;
    bytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }

  while (bytes.lengthInBytes > 100 * 1024 &&
      (processed.width > 240 || processed.height > 240)) {
    processed = img.copyResize(
      processed,
      width: (processed.width * 0.85).round(),
      height: (processed.height * 0.85).round(),
      interpolation: img.Interpolation.average,
    );
    bytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }
  return bytes;
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
